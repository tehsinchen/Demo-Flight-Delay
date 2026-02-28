data "aws_caller_identity" "current" {}

# Use the default VPC and pick a public subnet
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Find the latest baked AMI by name prefix
# data "aws_ami" "flightops_golden" {
#   most_recent = true
#   owners      = [data.aws_caller_identity.current.account_id]

#   filter {
#     name   = "name"
#     values = ["flightops-k3s-argocd-*"]
#   }
# }

# Choose the first subnet that has map_public_ip_on_launch = true
# (Most default VPC public subnets are configured that way)
data "aws_subnet" "selected" {
  id = element(data.aws_subnets.default_public.ids, 0)
}