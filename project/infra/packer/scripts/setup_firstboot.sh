#!/usr/bin/env bash
set -euo pipefail

echo "[BOOT] Starting..."

# Create the first-boot orchestrator and ECR refresh systemd units
sudo tee /opt/flightops/bin/firstboot.sh >/dev/null <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
CONFIG="/etc/flightops/config.env"
KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
export KUBECONFIG

log() { echo "[firstboot] $(date -Is) $*"; }

# Wait for config written by EC2 user_data
for i in {1..60}; do
  [[ -f "$CONFIG" ]] && break
  sleep 2
done
if [[ ! -f "$CONFIG" ]]; then
  log "Config not found at $CONFIG"; exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG"

# Create ArgoCD Application for Git repo with ECR image overrides
log "Applying ArgoCD Application..."
sudo envsubst < /opt/flightops/argocd/argocd-app-template.yaml > /opt/flightops/argocd/argocd-app.yaml
sudo cat /opt/flightops/argocd/argocd-app.yaml
kubectl apply -f /opt/flightops/argocd/argocd-app.yaml

# --- ECR pull-secret refresher (handles token expiry) ---
install_refresh() {
  mkdir -p /opt/flightops/bin

  cat >/opt/flightops/bin/ecr_pullsecret_refresh.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
CONFIG="/etc/flightops/config.env"
# shellcheck disable=SC1090
source "$CONFIG"

# Namespaces we may deploy into; adjust freely
NAMESPACES=("flightops-dev" "argocd")
SECRET_NAME="ecr-creds"

# Ensure AWS CLI exists
if ! command -v aws >/dev/null 2>&1; then
  echo "[ecr-refresh] aws CLI not found" >&2
  exit 1
fi

PASS=$(aws ecr get-login-password --region "${REGION}")
for ns in "${NAMESPACES[@]}"; do
  if kubectl get ns "$ns" >/dev/null 2>&1; then
    echo "[ecr-refresh] Updating secret in $ns"
    kubectl -n "$ns" delete secret "$SECRET_NAME" >/dev/null 2>&1 || true
    kubectl -n "$ns" create secret docker-registry "$SECRET_NAME" \
      --docker-server="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com" \
      --docker-username="AWS" \
      --docker-password="$PASS" >/dev/null 2>&1 || true
    kubectl -n "$ns" patch serviceaccount default \
      -p "{\"imagePullSecrets\": [{\"name\": \"${SECRET_NAME}\"}]}" >/dev/null 2>&1 || true
  fi
done
EOS
  chmod +x /opt/flightops/bin/ecr_pullsecret_refresh.sh

  # systemd service
  cat >/etc/systemd/system/flightops-ecr-refresh.service <<'EOS'
[Unit]
Description=Refresh ECR imagePullSecret across namespaces
After=network-online.target k3s.service
Wants=network-online.target

[Service]
Type=oneshot
EnvironmentFile=/etc/flightops/config.env
ExecStart=/opt/flightops/bin/ecr_pullsecret_refresh.sh
EOS

  # systemd timer
  cat >/etc/systemd/system/flightops-ecr-refresh.timer <<'EOS'
[Unit]
Description=Run ECR pull secret refresh every 6 hours

[Timer]
OnBootSec=2m
OnUnitActiveSec=6h
Unit=flightops-ecr-refresh.service

[Install]
WantedBy=timers.target
EOS

  systemctl daemon-reload
  # Run once immediately so first sync can pull private images
  /opt/flightops/bin/ecr_pullsecret_refresh.sh || true
  systemctl enable --now flightops-ecr-refresh.timer
}

install_refresh

log "First boot completed."
BASH
chmod +x /opt/flightops/bin/firstboot.sh

# Systemd unit to execute first boot orchestration
sudo tee /etc/systemd/system/flightops-firstboot.service >/dev/null <<'UNIT'
[Unit]
Description=FlightOps first boot (k3s + ArgoCD + App)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/flightops/bin/firstboot.sh

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable flightops-firstboot.service
