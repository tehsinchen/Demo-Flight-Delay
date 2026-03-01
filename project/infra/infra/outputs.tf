output "public_ip" {
  description = "Instance public IP"
  value       = aws_instance.k3s.public_ip
}

output "frontend_url" {
  description = "Frontend URL (no port number)"
  value       = "http://${aws_instance.k3s.public_ip}/"
}

output "argocd_url" {
  description = "ArgoCD UI URL"
  value       = "http://${aws_instance.k3s.public_ip}/argocd"
}