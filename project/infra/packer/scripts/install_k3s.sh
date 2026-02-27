#!/usr/bin/env bash
set -euo pipefail

# Basics
sudo dnf -y update
sudo dnf -y install unzip jq tar awscli

# Install k3s
export INSTALL_K3S_SKIP_START=true
export K3S_KUBECONFIG_MODE="644"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh - || {
  echo "k3s install failed"
  exit 1
}

# Prep our dirs
sudo mkdir -p /etc/flightops /opt/flightops/bin /opt/flightops/argocd
sudo chown -R root:root /etc/flightops /opt/flightops