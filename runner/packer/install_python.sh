#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Prereqs
apt-get update -y
apt-get install -y --no-install-recommends software-properties-common ca-certificates curl

# Keep system Python healthy: the distro setuptools provides _distutils_hack
apt-get install -y --no-install-recommends python3-setuptools  # DO NOT pip-upgrade globally

# Add Deadsnakes and install Python 3.13 + venv
add-apt-repository -y ppa:deadsnakes/ppa
apt-get update -y
apt-get install -y --no-install-recommends python3.13 python3.13-venv python3.13-dev

# Create an isolated toolchain for your AMI (never touch system site-packages)
PY313_VENV=/opt/py313
python3.13 -m venv "${PY313_VENV}"
# shellcheck disable=SC1090
. "${PY313_VENV}/bin/activate"

# Modern packaging only INSIDE the venv
pip install --upgrade pip setuptools wheel

# Install your build-time requirements (optional) if provided to Packer
REQS="${1:-/tmp/requirements.txt}"
if [[ -s "$REQS" ]]; then
  pip install --no-cache-dir -r "$REQS"
  pip cache purge || true
fi

# Quick sanity
python --version
pip --version
