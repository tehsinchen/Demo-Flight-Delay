packer {
  required_plugins {
    amazon = { source = "github.com/hashicorp/amazon", version = ">= 1.2.0" }
  }
}

variable "aws_profile" { default = "aws-dev" }
variable "aws_region" { default = "ap-southeast-1" }
variable "ami_name" { default = "demo-flight-delay-runner-ubuntu-2404" }
variable "instance_type" { default = "t3.small" }

source "amazon-ebs" "ubuntu" {
  profile       = var.aws_profile
  region        = var.aws_region
  instance_type = var.instance_type
  ami_name      = "${var.ami_name}-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      virtualization-type = "hvm"
      root-device-type    = "ebs"
    }
    owners      = ["099720109477"] # Canonical
    most_recent = true
  }

  temporary_iam_instance_profile_policy_document {
    Statement {
      Action   = ["ssm:*", "ssmmessages:*", "ec2messages:*"]
      Effect   = "Allow"
      Resource = ["*"]
    }
    Version = "2012-10-17"
  }

  ssh_username = "ubuntu"
}

build {
  name    = "github-runner-ami"
  sources = ["source.amazon-ebs.ubuntu"]

  # --- Upload installer scripts ---
  provisioner "file" {
    source      = "install_base.sh"
    destination = "/tmp/install_base.sh"
  }
  provisioner "file" {
    source      = "requirements.txt"
    destination = "/tmp/requirements.txt"
  }
  provisioner "file" {
    source      = "install_python.sh"
    destination = "/tmp/install_python.sh"
  }
  provisioner "file" {
    source      = "install_awscli.sh"
    destination = "/tmp/install_awscli.sh"
  }
  provisioner "file" {
    source      = "install_terraform.sh"
    destination = "/tmp/install_terraform.sh"
  }
  provisioner "file" {
    source      = "install_docker.sh"
    destination = "/tmp/install_docker.sh"
  }
  provisioner "file" {
    source      = "install_runner.sh"
    destination = "/tmp/install_runner.sh"
  }

  # --- Make scripts executable ---
  provisioner "shell" {
    inline = ["sudo chmod +x /tmp/install_*.sh"]
  }

  # --- Run installers in order ---
  provisioner "shell" { inline = ["sudo /tmp/install_base.sh"] }
  provisioner "shell" { inline = ["sudo /tmp/install_python.sh"] }
  provisioner "shell" { inline = ["sudo /tmp/install_awscli.sh"] }
  provisioner "shell" { inline = ["sudo /tmp/install_terraform.sh"] }
  provisioner "shell" { inline = ["sudo /tmp/install_docker.sh"] }
  provisioner "shell" { inline = ["sudo /tmp/install_runner.sh"] }
}