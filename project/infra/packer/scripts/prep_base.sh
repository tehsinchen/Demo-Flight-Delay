#!/usr/bin/env bash
set -euo pipefail

# Basics
sudo dnf -y update
sudo dnf -y install unzip jq tar awscli

# Prep our dirs
sudo mkdir -p /etc/flightops /opt/flightops/bin /opt/flightops/argocd
sudo chown -R root:root /etc/flightops /opt/flightops
