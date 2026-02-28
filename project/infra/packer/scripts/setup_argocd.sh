#!/usr/bin/env bash
set -euo pipefail

ARGOCD_VERSION="v3.3.2"

# Download official ArgoCD install manifest with retries; write via sudo tee to avoid perms issues
curl -fL --retry 5 --retry-all-errors --connect-timeout 10 \
  "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml" \
  | sudo tee /opt/flightops/argocd/install.yaml >/dev/null

# Start k3s
systemctl enable k3s
systemctl start k3s

# Wait for node to be Ready
log "Waiting for Kubernetes node to be Ready..."
for i in {1..180}; do
  READY=$(kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  [[ "$READY" == "True" ]] && break
  sleep 2
done

# Install ArgoCD (CRDs + controllers)
log "Applying ArgoCD install manifest..."
kubectl create namespace argocd
kubectl apply -n argocd -f /opt/flightops/argocd/install.yaml

# Wait for Application CRD to exist
log "Waiting for ArgoCD CRDs..."
for i in {1..120}; do
  kubectl get crd applications.argoproj.io >/dev/null 2>&1 && break
  sleep 2
done

# Make server HTTP-only (we're using Ingress on port 80)
# Expose ArgoCD via Traefik at /argocd
kubectl apply -f /opt/flightops/argocd/networking.yaml || true

# Ensure Traefik is up (k3s default ingress controller)
kubectl -n kube-system rollout status deploy/traefik --timeout=180s || true

# Wait for ArgoCD server to start (best-effort)
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s || true
