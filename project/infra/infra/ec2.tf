locals {
  config_env_script = <<-EOT
#!/bin/bash
set -euo pipefail
mkdir -p /etc/flightops
cat >/etc/flightops/config.env <<'CFG'
REGION=${var.aws_region}
ACCOUNT_ID=${data.aws_caller_identity.current.account_id}
GIT_URL=${var.git_app.url}
GIT_REVISION=${var.git_app.revision}
GIT_PATH=${var.git_app.path}
CFG
EOT
}

resource "aws_instance" "k3s" {
  # ami                         = data.aws_ami.flightops_golden.id
  ami                         = "ami-0ac0e4288aa341886"
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