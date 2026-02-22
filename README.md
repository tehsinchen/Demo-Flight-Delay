# Fine‑grained PAT for GitHub Self‑Hosted Runner (Repo Level)

This guide explains how to create a **fine‑grained personal access token (PAT)** that can be used **by an EC2 instance** at boot to register itself as a **repo‑level** self‑hosted runner.

> ⚠️ The runner does **not** use this PAT to run jobs. The PAT is only used at boot to call GitHub’s API to obtain a **short‑lived registration token** (valid ~1 hour), which is then passed to `config.sh`. [2](https://github.apidog.io/api-3489141)

## Prerequisites

- You have **Admin** permission on the target repository (repo‑level runner requires admin access to create registration/remove tokens). [6](https://github.com/orgs/community/discussions/43524)

## Steps (GitHub UI)

1. In GitHub, click your avatar → **Settings** → **Developer settings** → **Personal access tokens** → **Fine‑grained tokens** → **Generate new token**. [5](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
2. **Token name**: e.g., `ec2-runner-register`.
3. **Resource owner**: select the organization or user that owns the repository. [5](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
4. **Repository access**: select **Only select repositories**, then pick your target repo(s). [5](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
5. **Permissions** (Repository permissions):
   - **Administration: Read and write** — required so the token can call the self‑hosted runner registration/remove endpoints for the repository. [7](https://blog.madkoo.net/2023/07/24/register-self-hosted/)
6. Set a **reasonable expiration** and click **Generate token**. Copy the token (`ghp_…`) now—GitHub will not show it again. [5](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)

> **Note**: Classic PATs using `repo` scope also work for this API, but fine‑grained tokens are recommended for least privilege and scoping to specific repos. [2](https://github.apidog.io/api-3489141)[5](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)

## Store the PAT in AWS Secrets Manager

Create or update a secret with the fields your bootstrap script expects:

```bash
aws secretsmanager create-secret \
  --name github/ci/runner-settings \
  --secret-string '{
    "github_owner": "YOUR_ORG_OR_USER",
    "github_repo":  "YOUR_REPO",
    "github_pat":   "ghp_XXXXXXXXXXXXXXXXXXXX",
    "runner_labels": "ubuntu-24.04,docker,small",
    "runner_name_prefix": "gha-runner",
    "runner_dir": "/opt/actions-runner"
  }' \
  --region ap-southeast-1
```