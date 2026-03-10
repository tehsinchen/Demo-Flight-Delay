#!/usr/bin/env bash
set -euo pipefail

echo "[ARGO] Starting..."

ARGOCD_VERSION="v3.3.2"
# Download official ArgoCD install manifest with retries; write via sudo tee to avoid perms issues
curl -fL --retry 5 --retry-all-errors --connect-timeout 10 \
  "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml" \
  | sudo tee /opt/flightops/argocd/install.yaml >/dev/null


# Create the first-boot orchestrator and ECR refresh systemd units
sudo tee /opt/flightops/bin/firstboot.sh >/dev/null <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
CONFIG="/etc/flightops/config.env"
source "$CONFIG"
KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
export KUBECONFIG

log() { echo "[firstboot] $(date -Is) $*"; }

# Wait for k3s kubeconfig and API ready
for i in {1..120}; do
  [[ -f "$KUBECONFIG" ]] && break
  sleep 2
done
if [[ ! -f "$KUBECONFIG" ]]; then
  log "KUBECONFIG not found at $KUBECONFIG"; exit 1
fi
# Wait for config written by EC2 user_data
for i in {1..60}; do
  [[ -f "$CONFIG" ]] && break
  sleep 2
done
if [[ ! -f "$CONFIG" ]]; then
  log "Config not found at $CONFIG"; exit 1
fi

log "Waiting for Kubernetes node to be Ready..."
for i in {1..180}; do
  READY=$(kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  [[ "$READY" == "True" ]] && break
  sleep 2
done

log "Applying ArgoCD install manifest..."
kubectl create namespace argocd
kubectl apply -n argocd -f /opt/flightops/argocd/install.yaml --server-side --force-conflicts
kubectl patch configmap/argocd-cm -n argocd --type merge -p '{"data":{"kustomize.buildOptions":"--enable-helm"}}'

log "Waiting for ArgoCD CRDs..."
for i in {1..120}; do
  kubectl get crd applications.argoproj.io >/dev/null 2>&1 && break
  sleep 2
done

log "Make server HTTP-only and expose ArgoCD via Traefik at /argocd"
kubectl apply -f /opt/flightops/argocd/networking.yaml --server-side --force-conflicts || true
if kubectl -n kube-system get deploy traefik >/dev/null 2>&1; then
  log "Waiting for Traefik Deployment to be Available..."
  kubectl -n kube-system rollout status deploy/traefik --timeout=300s || true
else
  log "Traefik Deployment not found. Skipping Traefik wait."
fi

log "Wait for ArgoCD server to start"
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s || true

log "Create ArgoCD Application for Git repo with ECR image overrides"
kubectl apply -f /opt/flightops/argocd/argocd-app.yaml --server-side --force-conflicts

log "First boot completed."
BASH

chmod +x /opt/flightops/bin/firstboot.sh
