#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y --no-install-recommends \
  curl jq git tar unzip ca-certificates software-properties-common \
  gnupg apt-transport-https lsb-release \
  python3-setuptools

# Force reinstall in case a previous layer left only the .pth file
apt-get update -y
apt-get install -y --reinstall python3-setuptools

# Helpful for image size cleanliness
apt-get -y autoremove
apt-get -y clean
