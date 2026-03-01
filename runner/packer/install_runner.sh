#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y --no-install-recommends curl jq ca-certificates tar

# Dedicated, non-privileged account to own/operate the runner
id -u github >/dev/null 2>&1 || \
  useradd --system --create-home --home-dir /home/github --shell /usr/sbin/nologin github

RUNNER_DIR="/opt/actions-runner"
mkdir -p "${RUNNER_DIR}"
cd "${RUNNER_DIR}"

# Allow pin via env RUNNER_VERSION (e.g., v2.331.0). If not set, fetch latest release tag.
if [[ -z "${RUNNER_VERSION:-}" ]]; then
  RUNNER_VERSION="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name)"
fi

ARCH="x64"  # amd64 host
echo "Installing GitHub Actions runner ${RUNNER_VERSION} to ${RUNNER_DIR}"
curl -fsSL -o "actions-runner-linux-${ARCH}.tar.gz" \
  "https://github.com/actions/runner/releases/download/${RUNNER_VERSION}/actions-runner-linux-${ARCH}-${RUNNER_VERSION#v}.tar.gz"
tar xzf "actions-runner-linux-${ARCH}.tar.gz"
rm -f "actions-runner-linux-${ARCH}.tar.gz"

# Pre-create the work dir to avoid surprises; config.sh will honor --work
mkdir -p _work

# Install OS deps the runner expects (helper script is idempotent)
./bin/installdependencies.sh || true

# Ownership: the runner must be writable by the account that will run config.sh
chown -R github:github "${RUNNER_DIR}"
echo "Runner files deployed to ${RUNNER_DIR} and owned by 'github'."
