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
KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
export KUBECONFIG

log() { echo "[firstboot] $(date -Is) $*"; }

# Wait for node to be Ready
log "Waiting for Kubernetes node to be Ready..."
for i in {1..180}; do
  READY=$(kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  [[ "$READY" == "True" ]] && break
  sleep 2
done

# Wait for k3s kubeconfig and API ready
for i in {1..120}; do
  [[ -f "$KUBECONFIG" ]] && break
  sleep 2
done
if [[ ! -f "$KUBECONFIG" ]]; then
  log "KUBECONFIG not found at $KUBECONFIG"; exit 1
fi

log "Waiting for Kubernetes API..."
for i in {1..120}; do
  if kubectl --request-timeout=5s get --raw="/readyz" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# Wait for config written by EC2 user_data
for i in {1..60}; do
  [[ -f "$CONFIG" ]] && break
  sleep 2
done
if [[ ! -f "$CONFIG" ]]; then
  log "Config not found at $CONFIG"; exit 1
fi

# Install ArgoCD (CRDs + controllers)
log "Applying ArgoCD install manifest..."
kubectl create namespace argocd
kubectl apply -n argocd -f /opt/flightops/argocd/install.yaml --server-side --force-conflicts

# Wait for Application CRD to exist
log "Waiting for ArgoCD CRDs..."
for i in {1..120}; do
  kubectl get crd applications.argoproj.io >/dev/null 2>&1 && break
  sleep 2
done

# Make server HTTP-only and expose ArgoCD via Traefik at /argocd
kubectl apply -f /opt/flightops/argocd/networking.yaml --server-side --force-conflicts || true

# Does a Deployment named 'traefik' exist in kube-system?
if kubectl -n kube-system get deploy traefik >/dev/null 2>&1; then
  log "Waiting for Traefik Deployment to be Available..."
  kubectl -n kube-system rollout status deploy/traefik --timeout=300s || true
else
  log "Traefik Deployment not found. Skipping Traefik wait."
fi

# Wait for ArgoCD server to start (best-effort)
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s || true

source "$CONFIG"
# Create ArgoCD Application for Git repo with ECR image overrides
log "Applying ArgoCD Application..."
kubectl apply -f /opt/flightops/argocd/argocd-app.yaml --server-side --force-conflicts

# --- ECR pull-secret refresher (handles token expiry) ---
install_refresh() {
  mkdir -p /opt/flightops/bin

  cat >/opt/flightops/bin/ecr_pullsecret_refresh.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
CONFIG="/etc/flightops/config.env"
# shellcheck disable=SC1090
source "$CONFIG"

# Namespaces we may deploy into; adjust freely
NAMESPACES=("flightops-dev" "argocd")
SECRET_NAME="ecr-creds"

# Ensure AWS CLI exists
if ! command -v aws >/dev/null 2>&1; then
  log "[ecr-refresh] aws CLI not found" >&2
  exit 1
fi

PASS=$(aws ecr get-login-password --region "${REGION}")
for ns in "${NAMESPACES[@]}"; do
  if kubectl get ns "$ns" >/dev/null 2>&1; then
    log "[ecr-refresh] Updating secret in $ns"
    kubectl -n "$ns" delete secret "$SECRET_NAME" >/dev/null 2>&1 || true
    kubectl -n "$ns" create secret docker-registry "$SECRET_NAME" \
      --docker-server="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com" \
      --docker-username="AWS" \
      --docker-password="$PASS" >/dev/null 2>&1 || true
    kubectl -n "$ns" patch serviceaccount default \
      -p "{\"imagePullSecrets\": [{\"name\": \"${SECRET_NAME}\"}]}" >/dev/null 2>&1 || true
  fi
done
EOS
  chmod +x /opt/flightops/bin/ecr_pullsecret_refresh.sh

  # systemd service
  cat >/etc/systemd/system/flightops-ecr-refresh.service <<'EOS'
[Unit]
Description=Refresh ECR imagePullSecret across namespaces
After=network-online.target k3s.service
Wants=network-online.target

[Service]
Type=oneshot
EnvironmentFile=/etc/flightops/config.env
ExecStart=/opt/flightops/bin/ecr_pullsecret_refresh.sh
EOS

  # systemd timer
  cat >/etc/systemd/system/flightops-ecr-refresh.timer <<'EOS'
[Unit]
Description=Run ECR pull secret refresh every 6 hours

[Timer]
OnBootSec=2m
OnUnitActiveSec=6h
Unit=flightops-ecr-refresh.service

[Install]
WantedBy=timers.target
EOS

  systemctl daemon-reload
  # Run once immediately so first sync can pull private images
  /opt/flightops/bin/ecr_pullsecret_refresh.sh | tee /var/log/firstpullsecret.log
  systemctl enable --now flightops-ecr-refresh.timer
}

install_refresh

log "First boot completed."
BASH

chmod +x /opt/flightops/bin/firstboot.sh
