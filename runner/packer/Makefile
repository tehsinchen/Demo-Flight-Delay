PROFILE ?= aws-dev
REGION ?= ap-southeast-1

init:
	packer init .
build: fmt
	packer build -var 'aws_region=${REGION}' -var 'aws_profile=${PROFILE}' .
plan: fmt
	packer validate .
fmt:
	packer fmt .
login:
	aws sso login --profile ${PROFILE}