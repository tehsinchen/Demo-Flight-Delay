#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Deadsnakes PPA for Python 3.13 on Ubuntu 24.04
add-apt-repository -y ppa:deadsnakes/ppa
apt-get update -y

# Install Python 3.13; headers are useful for building native wheels
apt-get install -y python3.13 python3.13-venv python3.13-dev

# Bootstrap pip for that interpreter, then upgrade core packaging tools
python3.13 -m ensurepip --upgrade --default-pip
python3.13 -m pip install --upgrade pip setuptools wheel

# Quick sanity
python3.13 --version
python3.13 -m pip --version

REQS="${1:-/tmp/requirements.txt}"
if [[ ! -s "$REQS" ]]; then
  echo "requirements.txt not found at $REQS (or empty)"; exit 1
fi

# Install globally into the Python 3.13 site-packages for this AMI
python3.13 -m pip install --no-cache-dir -r "$REQS"

# Optionally purge pip cache to keep the AMI small
python3.13 -m pip cache purge || true
