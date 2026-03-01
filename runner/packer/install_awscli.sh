#!/usr/bin/env bash
set -euo pipefail

curl -fsSL -o /tmp/awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
cd /tmp && unzip -q awscliv2.zip && sudo ./aws/install
aws --version

systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service || true
systemctl start  snap.amazon-ssm-agent.amazon-ssm-agent.service || true
systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service --no-pager || true
