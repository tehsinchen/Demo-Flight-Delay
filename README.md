# Demo-Flight-delay (IaC & GitOps)

This project demonstrates a fully automated, Infrastructure as Code (IaC) approach to provisioning a microservices-based application (frontend, backend, and data crawler) on AWS. Everything from the CI/CD runners to the Kubernetes cluster is managed entirely via Terraform, Packer, and ArgoCD.

## Prerequisites
Before deploying the infrastructure, ensure you have the following installed and configured locally:
* AWS CLI (authenticated via aws sso login or your preferred profile)
* Admin access to the target GitHub repository.
* Terraform
* Packer

## Deployment Guide
### Phase 1: Setup GitHub Runner Credentials
To allow EC2 instances to dynamically register as runners, we use a fine-grained GitHub PAT securely stored in AWS Secrets Manager.

#### 1. Generate the PAT (GitHub UI):
* Go to Settings → Developer settings → Personal access tokens → Fine‑grained tokens → Generate new token.
* Name: ec2-runner-register.
* Resource owner: Your organization or user.
* Repository access: Only select repositories -> Pick the target repo.
* Permissions: Administration: Read and write.
* Generate and copy the token (ghp_...).

#### 2. Store PAT in AWS Secrets Manager:
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
  --region YOUR_REGION \
  --profile YOUR_PROFILE
```

### Phase 2: Deploy Self-Hosted GitHub Runner
#### 1. Bake the Runner AMI:
```bash
cd runner/packer
# Ensure variables in github-runner-ami.pkr.hcl meet your requirements
make init
make build
```

#### 2. Provision the Runner Infrastructure:
```bash
cd ../infra
# Update backend.conf and variables.tf as needed
make init
make apply
```
The runner will automatically retrieve the secret at boot, install dependencies, and register itself to your GitHub repository.
![image](images/runner_1.png)

### Phase 3: Deploy Kubernetes Cluster & ArgoCD
#### 1. Bake the k3s + ArgoCD AMI:
```bash
cd project/infra/packer
# Ensure variables in al2023-k3s-argocd.pkr.hcl meet your requirements
make init
make build
```

#### 2. Provision the k3s Infrastructure:
```bash
cd ../infra
# Update backend.conf and variables.tf as needed
make init
make apply
```

### Phase 4: Bootstrap Application Images (CI/CD)
>⚠️ **Important Bootstrapping Note**:
Upon initial deployment, the ArgoCD pods for the application will sit in an ErrImagePull state. This is expected GitOps behavior because the infrastructure has provisioned the deployment manifests, but the actual Docker images have not yet been built and pushed to the newly created ECR repositories.

#### To resolve this and bring the app online:
1. Navigate to your repository's Actions tab on GitHub.
2. Select the Manual Build Service Images workflow.
3. Click Run workflow and select "all" services.
4. Wait for the pipeline to build and push images to ECR.
5. Once complete, you can manually delete the failing pods to trigger an immediate repull.

![image](images/runner_2.png)

## Accessing the Application
Once everything is green, the resources are exposed via the public IP of the k3s EC2 instance (outputted by Terraform).
#### Application Frontend: `http://<public-ip>/`
![image](images/frontend_1.png)![image](images/frontend_2.png)![image](images/frontend_3.png)

#### ELK UI: `http://<public-ip>/kibana`
![image](images/elk_1.png)

#### ArgoCD UI: `http://<public-ip>/argocd`
To retrieve the initial ArgoCD Admin Password:</br>
Connect to the EC2 instance via AWS SSM Session Manager and run:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```
Username is `admin`.

![image](images/argocd_1.png)
![image](images/argocd_2.png)

#### GitOps
Since `ApplyOutOfSyncOnly` is set to `true`, Argocd will sync only out-of-sync resources
![image](images/gitops_1.png)
![image](images/gitops_2.png)

## Helm & Kustomize Integration
This project utilizes a hybrid **Helm + Kustomize** architecture to maximize configuration reusability while maintaining strict environment isolation.
* **Helm (The Base):** A custom Helm chart is located in `charts/flightops/`. This acts as our single source of truth, managing default values, image versions, and conditional logic (e.g., toggling the ELK stack on or off via `values.yaml`).
* **Kustomize (The Overlays):** Environment-specific configurations (`dev`, `prod`) are managed via Kustomize in the `overlays/` directory. Kustomize natively inflates the local Helm chart using environment-specific values and applies localized patches (like resource limits or replica counts) without duplicating the base manifests.

### Deployment
ArgoCD natively handles the synchronization of this hybrid setup. The `--enable-helm` build option is configured globally in the `argocd-cm` ConfigMap, allowing ArgoCD to render the Helm chart dynamically during the Kustomize build phase.

## Logging & Observability (ELK Stack)
The application utilizes an integrated ELK stack (Elasticsearch, Kibana, Fluent-bit) for centralized log aggregation and observability.

* **Fluent-bit:** Deployed as a DaemonSet to automatically tail container logs. It utilizes a custom Lua script (`index.lua`) to dynamically compute Elasticsearch index prefixes based on the Kubernetes namespace and application labels (e.g., `flightops-frontend-2026.03.10`), ensuring clean data separation.
* **Elasticsearch:** Acts as the persistent storage engine for our log data.
* **Kibana:** Provides the visualization interface for monitoring application health and troubleshooting.

### Setup Log Distribution Dashboard
1. Navigate to **Stack Management > Data Views** and create a new data view with the index pattern `flightops-*` using `@timestamp` as the time field.
2. Navigate to **Dashboard**, click **Create dashboard**, and select Create visualization (Lens).
3. Select **Donut** or **Pie** as the chart type.
4. Drag the `es_prefix.keyword` field (generated by our Fluent-bit Lua script) into the **Slice** by section on the right panel.
5. Ensure the **Metric** is set to Count of records.
6. Save the visualization.
![image](images/elk_2.png)

## Useful Commands for Debugging
Since SSH is disabled, use AWS SSM to connect to the instances to run these commands.

#### Instance Bootstrapping & Cloud-Init:
```bash
cat /var/log/cloud-init.log
cat /var/log/cloud-init-output.log
```

#### ArgoCD:
```bash
kubectl -n argocd get pods
kubectl -n argocd get svc,ingress
kubectl -n argocd logs deploy/argocd-server -n argocd --tail=20
kubectl -n argocd get applications.argoproj.io flightops
```

#### Kubernetes (k3s):
```bash
kubectl -n flightops-dev get pods
```