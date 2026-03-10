# Create ECR repos and lifecycle policy to delete untagged images aggressively
locals {
  ecr_lifecycle_untagged = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Delete untagged images ASAP (keep at most 1 due to AWS constraints)"
        selection = {
          tagStatus   = "untagged"
          countType   = "imageCountMoreThan"
          countNumber = 1
        }
        action = { type = "expire" }
      }
    ]
  })
}

resource "aws_ecr_repository" "repos" {
  for_each = toset(var.ecr_repositories)

  name                 = each.value
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }

  encryption_configuration {
    encryption_type = "AES256"
  }

  force_delete = true
}

resource "aws_ecr_lifecycle_policy" "repo_policies" {
  for_each   = aws_ecr_repository.repos
  repository = each.value.name
  policy     = local.ecr_lifecycle_untagged
}

# output "ecr_repo_urls" {
#   value = {
#     for k, v in aws_ecr_repository.repos :
#     k => v.repository_url
#   }
#   description = "ECR repository URIs"
# }