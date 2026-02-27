#!/usr/bin/env bash
set -euo pipefail

sudo mkdir -p /opt/flightops/argocd
sudo chown -R root:root /opt/flightops/argocd

ARGOCD_VERSION="v2.9.6"

# Download official ArgoCD install manifest with retries; write via sudo tee to avoid perms issues
curl -fL --retry 5 --retry-all-errors --connect-timeout 10 \
  "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml" \
  | sudo tee /opt/flightops/argocd/install.yaml >/dev/null

# Make ArgoCD server run HTTP (insecure) because we're exposing via Traefik on port 80
cat <<'YAML' | sudo tee /opt/flightops/argocd/insecure-cm.yaml >/dev/null
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  server.insecure: "true"
YAML

# Expose ArgoCD at /argocd via Traefik (k3s default ingress controller)
cat <<'YAML' | sudo tee /opt/flightops/argocd/ingress.yaml >/dev/null
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd
  namespace: argocd
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  ingressClassName: traefik
  rules:
    - http:
        paths:
          - path: /argocd
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 80
YAML
