output "aws_region" { value = var.aws_region }
output "runner_subnet_id" { value = local.runner_subnet_id }
output "runner_security_group_id" { value = aws_security_group.runner.id }
output "runner_instance_profile_name" { value = aws_iam_instance_profile.ec2_runner_profile.name }
output "runner_instance_profile_arn" { value = aws_iam_instance_profile.ec2_runner_profile.arn }
output "runner_instance_type" { value = var.runner_instance_type }
output "ecr_repository_name" { value = aws_ecr_repository.repo.name }
output "ecr_repository_url" { value = aws_ecr_repository.repo.repository_url }

output "gha_access_key_id" {
  value       = aws_iam_access_key.gha_ci_key.id
  sensitive   = true
  description = "Use as GitHub Secret AWS_ACCESS_KEY_ID"
}

output "gha_secret_access_key" {
  value       = aws_iam_access_key.gha_ci_key.secret
  sensitive   = true
  description = "Use as GitHub Secret AWS_SECRET_ACCESS_KEY"
}
