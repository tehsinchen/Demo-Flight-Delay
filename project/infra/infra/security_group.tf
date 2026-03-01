resource "aws_security_group" "k3s_sg" {
  name        = "flightops-k3s-sg"
  description = "Allow HTTP for app and ArgoCD; block SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP (Traefik/ArgoCD/App)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}