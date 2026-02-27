packer {
  required_version = ">= 1.9.0"
  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "aws_profile" { default = "aws-dev" }
variable "aws_region" { default = "ap-southeast-1" }
locals {
  ami_name = "flightops-k3s-argocd-{{timestamp}}"
}

source "amazon-ebs" "al2023" {
  profile                     = var.aws_profile
  region                      = var.aws_region
  instance_type               = "t3.medium"
  ssh_username                = "ec2-user"
  ami_name                    = local.ami_name
  ami_description             = "AL2023 + k3s + Traefik + ArgoCD bake for FlightOps demo"
  associate_public_ip_address = true

  # Amazon Linux 2023 (x86_64) latest
  source_ami_filter {
    filters = {
      name                = "al2023-ami-*-x86_64"
      architecture        = "x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["137112412989"] # Amazon
    most_recent = true
  }

  tags = {
    Name = "flightops-ami-bake"
  }
}

build {
  name    = "flightops-k3s-argocd"
  sources = ["source.amazon-ebs.al2023"]

  provisioner "shell" {
    script          = "scripts/install_k3s.sh"
    execute_command = "sudo -E bash '{{ .Path }}'"
  }

  provisioner "shell" {
    script          = "scripts/setup_argocd.sh"
    execute_command = "sudo -E bash '{{ .Path }}'"
  }

  provisioner "shell" {
    script          = "scripts/setup_firstboot.sh"
    execute_command = "sudo -E bash '{{ .Path }}'"
  }
}
