variable "project" {
  type    = string
  default = "demo-flight-delay"
}

variable "aws_profile" {
  type    = string
  default = "aws-dev"
}

variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "runner_instance_type" {
  type    = string
  default = "t3.small"
}