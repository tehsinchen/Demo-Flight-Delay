#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Add Docker’s official GPG key & repo (Ubuntu 24.04 / noble)
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y

# Install Docker Engine + CLI + Buildx + Compose plugin
sudo apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# Enable and start services
sudo systemctl enable docker
sudo systemctl start docker

# Allow ubuntu user to use docker without sudo
if id "ubuntu" &>/dev/null; then
  sudo usermod -aG docker ubuntu
fi

# Pre-create buildx builder (optional; buildx action can also handle this)
sudo -u ubuntu bash -lc "
  docker buildx version || true
  docker buildx create --name ci-builder --use --driver docker-container || true
  docker buildx inspect --bootstrap || true
"

# Smoke tests
docker --version
docker compose version
docker buildx version