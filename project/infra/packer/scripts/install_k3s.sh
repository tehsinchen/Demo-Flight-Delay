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
