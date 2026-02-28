variable "aws_profile" {
  description = "AWS profile used to deploy"
  type        = string
  default     = "aws-dev"
}

variable "aws_region" {
  description = "AWS Region to deploy to"
  type        = string
  default     = "ap-southeast-1"
}

variable "instance_type" {
  description = "EC2 instance type for the k3s+ArgoCD host"
  type        = string
  default     = "t3.medium"
}

variable "root_volume_size" {
  description = "Root EBS volume size (GiB)"
  type        = number
  default     = 20
}

variable "ecr_repositories" {
  description = "List of ECR repository names to create"
  type        = list(string)
  default = [
    "flight-ops/frontend",
    "flight-ops/backend",
    "flight-ops/crawler",
  ]
}

variable "git_app" {
  description = "Map of Git settings for ArgoCD Application"
  type = object({
    url      = string # e.g., https://github.com/your-org/your-repo.git
    revision = string # e.g., main
    path     = string # e.g., overlays/dev or overlays/prod
    ns       = string # e.g., flightops-dev
  })
  default = {
    url      = "https://github.com/tehsinchen/Demo-Flight-Delay.git"
    revision = "dev"
    path     = "project/k8s/overlays/dev"
    ns       = "flightops-dev"
  }
}