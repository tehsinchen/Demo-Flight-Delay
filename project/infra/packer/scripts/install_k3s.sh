#!/usr/bin/env bash
set -euo pipefail

echo "[K3S] Starting..."
# Install k3s
export INSTALL_K3S_SKIP_START=true
export K3S_KUBECONFIG_MODE="644"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh - || {
  echo "k3s install failed"
  exit 1
}

# Setup ECR Credential
VERSION="v1.31.0"
ARCH_RAW="$(uname -m)"
case "$ARCH_RAW" in
  x86_64|amd64)   ARCH="amd64" ;;
  aarch64|arm64)  ARCH="arm64" ;;
  *) echo "Unsupported arch: $ARCH_RAW"; exit 1 ;;
esac

BIN_DIR="/usr/local/bin"                            # Where we’ll drop the binary
CFG_DIR="/var/lib/kubelet/credential-provider"      # Kubelet-readable config dir
CFG_FILE="${CFG_DIR}/config.yaml"

echo "---[ 1) Install ecr-credential-provider binary ]---"
sudo mkdir -p "$BIN_DIR" "$CFG_DIR"
# Official artifact hosted by Kubernetes project for cloud-provider-aws
URL="https://storage.googleapis.com/k8s-artifacts-prod/binaries/cloud-provider-aws/${VERSION}/linux/${ARCH}/ecr-credential-provider-linux-${ARCH}"
sudo curl -fsSL "$URL" -o "${BIN_DIR}/ecr-credential-provider"
sudo chmod +x "${BIN_DIR}/ecr-credential-provider"

echo "---[ 2) Create the kubelet CredentialProviderConfig ]---"
sudo tee "$CFG_FILE" >/dev/null <<'EOF'
apiVersion: kubelet.config.k8s.io/v1
kind: CredentialProviderConfig
providers:
  - name: ecr-credential-provider
    apiVersion: credentialprovider.kubelet.k8s.io/v1
    matchImages:
      - "*.dkr.ecr.*.amazonaws.com"
    defaultCacheDuration: "12h"
EOF

echo "---[ 3) Wire kubelet via k3s config ]---"
sudo mkdir -p /etc/rancher/k3s
CFG=/etc/rancher/k3s/config.yaml
# Append only if not already present
sudo grep -q "image-credential-provider-bin-dir=" "$CFG" 2>/dev/null || \
  sudo tee -a "$CFG" >/dev/null <<EOF
kubelet-arg:
  - "image-credential-provider-bin-dir=${BIN_DIR}"
  - "image-credential-provider-config=${CFG_FILE}"
EOF
cat $CFG

echo "[K3S] Completed"