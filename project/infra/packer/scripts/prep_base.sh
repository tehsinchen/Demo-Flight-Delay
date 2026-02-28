#!/usr/bin/env bash
set -euo pipefail

echo "[BASE] Starting..."
# Basics
sudo dnf -y update
sudo dnf -y install unzip jq tar awscli

# Prep our dirs
sudo mkdir -p /etc/flightops /opt/flightops/bin /opt/flightops/argocd
sudo mv /tmp/networking.yaml /opt/flightops/argocd/networking.yaml
sudo mv /tmp/argocd-app-template.yaml /opt/flightops/argocd/argocd-app-template.yaml
sudo chown -R root:root /etc/flightops /opt/flightops
