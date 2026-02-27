resource "aws_iam_role" "ec2_role" {
  name               = "flightops-k3s-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Attach SSM + ECR read access
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Add GetAuthorizationToken explicitly for aws ecr get-login-password
data "aws_iam_policy_document" "ecr_extra" {
  statement {
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ecr_extra" {
  name   = "flightops-ecr-extra"
  policy = data.aws_iam_policy_document.ecr_extra.json
}

resource "aws_iam_role_policy_attachment" "ecr_extra_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ecr_extra.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "flightops-k3s-ec2-profile"
  role = aws_iam_role.ec2_role.name
}