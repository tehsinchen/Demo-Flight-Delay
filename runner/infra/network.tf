data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "in_default_vpc" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "random_shuffle" "choose_subnet" {
  input        = data.aws_subnets.in_default_vpc.ids
  result_count = 1
}

locals {
  runner_subnet_id = random_shuffle.choose_subnet.result[0]
}

resource "aws_security_group" "runner" {
  name        = "${local.name}-runner-sg"
  description = "Self-hosted runner SG (no inbound; SSM only)"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}