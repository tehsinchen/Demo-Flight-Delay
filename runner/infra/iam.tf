data "aws_iam_policy_document" "ec2_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ec2_runner_role" {
  name               = "${var.project}-ec2-runner-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_runner_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.ec2_runner_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_policy" "ecr_rw" {
  name = "${var.project}-ecr-rw"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["ecr:*"],
      Resource = "*"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "ecr_rw_attach" {
  role       = aws_iam_role.ec2_runner_role.name
  policy_arn = aws_iam_policy.ecr_rw.arn
}


resource "aws_iam_policy" "read_secret_sm" {
  name = "${var.project}-read-github-sm"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["secretsmanager:GetSecretValue"],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "read_secret_sm_attach" {
  role       = aws_iam_role.ec2_runner_role.name
  policy_arn = aws_iam_policy.read_secret_sm.arn
}


resource "aws_iam_instance_profile" "ec2_runner_profile" {
  name = "${var.project}-ec2-runner-profile"
  role = aws_iam_role.ec2_runner_role.name
}

data "aws_iam_policy_document" "gha_runner_actions" {
  statement {
    sid       = "EC2RunStopDescribe"
    effect    = "Allow"
    actions   = ["ec2:*"]
    resources = ["*"]
  }
  statement {
    sid       = "PassRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.ec2_runner_role.arn]
  }
}

resource "aws_iam_policy" "gha_runner_actions" {
  name   = "${var.project}-gha-ec2-actions"
  policy = data.aws_iam_policy_document.gha_runner_actions.json
}
