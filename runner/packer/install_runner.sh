#!/usr/bin/env bash
set -euo pipefail

# Prepare a home for the runner
sudo -u github bash -lc 'mkdir -p ~/actions-runner && cd ~/actions-runner && \
  curl -fsSL -o runner.tgz https://github.com/actions/runner/releases/download/v2.325.0/actions-runner-linux-x64-2.325.0.tar.gz && \
  tar xzf runner.tgz && rm -f runner.tgz'
