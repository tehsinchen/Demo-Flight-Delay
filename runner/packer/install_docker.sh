#!/usr/bin/env bash
set -euo pipefail

# Convenience script is fine for a CI runner
curl -fsSL https://get.docker.com | sh

# Users
id -u github >/dev/null 2>&1 || useradd -m -s /bin/bash github
usermod -aG docker ubuntu || true
usermod -aG docker github || true

# Sanity
docker --version