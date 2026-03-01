resource "aws_instance" "runner" {
  ami                         = var.runner_ami_id
  instance_type               = var.runner_instance_type
  subnet_id                   = local.runner_subnet_id
  vpc_security_group_ids      = [aws_security_group.runner.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_runner_profile.name
  associate_public_ip_address = true

  instance_initiated_shutdown_behavior = "stop"

  # Harden IMDS
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/templates/user_data_runner.sh.tftpl", {
    secret_name = var.secret_name
    aws_region  = var.aws_region
  })

}
