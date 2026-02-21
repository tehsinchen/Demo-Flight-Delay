In Settings → Secrets and variables → Actions → New repository secret, add:


AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY – from terraform output (the GitHub IAM user).
AWS_REGION – e.g., ap-northeast-1.
RUNNER_AMI_ID – from your Packer build.
RUNNER_SUBNET_ID – from terraform output runner_subnet_id.
RUNNER_SG_ID – from terraform output runner_security_group_id.
RUNNER_INSTANCE_PROFILE – from terraform output runner_instance_profile_name.