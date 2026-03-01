locals {
  BCRYPT            = base64encode(var.argocd_admin_password)
  config_env_script = <<-EOT
#!/bin/bash
set -euo pipefail
mkdir -p /etc/flightops
cat >/etc/flightops/config.env <<'CFG'
REGION=${var.aws_region}
ACCOUNT_ID=${data.aws_caller_identity.current.account_id}
CFG

cat >/opt/flightops/argocd/argocd-app.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: flightops
  namespace: argocd
spec:
  project: default
  source:
    repoURL: "${var.git_app.url}"
    targetRevision: "${var.git_app.revision}"
    path: "${var.git_app.path}"
    kustomize:
      images:
        - frontend=${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/flight-ops/frontend:latest
        - backend=${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/flight-ops/backend:latest
        - crawler=${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/flight-ops/crawler:latest
  destination:
    server: https://kubernetes.default.svc
    namespace: "${var.git_app.ns}"
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
EOF

# Start k3s
systemctl enable k3s
systemctl start k3s

echo "[user_data] Running firstboot script..."
/opt/flightops/bin/firstboot.sh | tee /var/log/firstboot.log
echo "[user_data] Firstboot completed."
EOT
}

resource "aws_instance" "k3s" {
  ami = data.aws_ami.flightops_golden.id
  # ami                         = "ami-0ac0e4288aa341886"
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.selected.id
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids      = [aws_security_group.k3s_sg.id]

  user_data = local.config_env_script

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  monitoring = false
}