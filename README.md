# AusPost Senior DevOps Engineer - Technical Assessment

A complete reference implementation for the DevOps Candidate Technical Assessment using:

- **Python / FastAPI** for the application
- **Docker** for containerization
- **Docker Hub** for image storage
- **Kubernetes** for orchestration
- **Terraform** for AWS infrastructure (VPC + EKS + optional Route53 DNS)
- **GitHub Actions** for CI/CD
- **Ruff, pytest, Bandit, pip-audit and Trivy** for quality/security gates

> Replace placeholder values such as `yourdockerhubuser` and configure the GitHub secrets before publishing the repository.

## Architecture

```text
Developer
   |
   | feature branch / pull request
   v
GitHub Repository
   |
   +--> CI: lint -> unit tests -> Bandit -> pip-audit
   |                         |
   |                         +--> Docker build -> Trivy scan
   |                                           |
   | main only                                 v
   +--------------------------------------> Docker Hub
                                                |
                                                | immutable sha-* image
                                                v
GitHub CD (OIDC) ----------------------------> AWS EKS
                                                |
                                                v
                                  Kubernetes Deployment (2 pods)
                                                |
                                                v
                                     Service type LoadBalancer
                                                |
                                                v
                                          AWS Load Balancer
                                                |
                                                v
                                      Route53 application DNS
```

## Repository layout

```text
.
|-- app/                         Python FastAPI application
|-- tests/                       Unit tests
|-- Dockerfile                   Hardened non-root image
|-- requirements*.txt            Runtime/development dependencies
|-- .github/workflows/
|   |-- ci.yml                   Test, scan, build and Docker Hub publish
|   `-- deploy.yml               EKS deployment, health validation, rollback
|-- k8s/
|   |-- base/                    Reusable Kubernetes resources
|   `-- overlays/
|       |-- local/               Windows/Docker Desktop local lab
|       `-- aws/                 AWS load-balanced deployment
|-- terraform/aws/               VPC, EKS, GitHub OIDC and DNS
|-- scripts/                     Bash/PowerShell smoke tests
`-- docs/                        Architecture and interview notes
```

## Assessment requirement mapping

| Assessment item | Implementation |
|---|---|
| Simple app | `app/main.py` |
| `/healthz` success + version | `GET /healthz` |
| Unit tests | `tests/test_main.py`, CI `pytest` |
| Minimal container | `python:3.12-slim-bookworm` |
| Non-root container | UID/GID `10001`, Kubernetes `runAsNonRoot` |
| Environment config | `APP_NAME`, `APP_VERSION`, `PORT` |
| Code security scanning | Bandit + pip-audit |
| Image security scanning | Trivy HIGH/CRITICAL gate |
| Artifact registry | Docker Hub |
| Kubernetes manifests | `k8s/base` + Kustomize overlays |
| Load balancer | AWS overlay Service `type: LoadBalancer` |
| Domain | optional Terraform Route53 record |
| Infrastructure as Code | `terraform/aws` |
| Automated deployment | `.github/workflows/deploy.yml` |
| Pull registry image | Kubernetes deployment uses Docker Hub image |
| Rollout | rolling update, `kubectl rollout status` |
| Rollback | `kubectl rollout undo` on failed rollout |
| Health validation | temporary curl pod checks `/healthz` + image version |
| Main-branch trigger | CI on push to main; CD on successful CI workflow |
| Latest endpoint content | `APP_VERSION=sha-<commit>` verified after deployment |
| Least privilege bonus | no SA token, restricted pod capabilities, GitHub OIDC, namespace-scoped EKS access |
| No hardcoded cloud secrets | GitHub OIDC for AWS; Docker Hub token stored as GitHub secret |

## Quick local application test on Windows

### Windows PowerShell

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements-dev.txt
pytest
ruff check app tests
bandit -r app -c pyproject.toml
pip-audit -r requirements.txt
$env:APP_VERSION = "local-1.0.0"
uvicorn app.main:app --host 0.0.0.0 --port 8080
```

In another terminal:

```powershell
Invoke-RestMethod http://localhost:8080/healthz
```

Expected shape:

```json
{"status":"success","application":"auspost-devops-demo","version":"local-1.0.0"}
```

## Docker

```powershell
$DockerUser = "YOUR_DOCKERHUB_USERNAME"
$Version = "1.0.0"
docker build --build-arg APP_VERSION=$Version -t "$DockerUser/auspost-devops-demo:$Version" .
docker run --rm -p 8080:8080 "$DockerUser/auspost-devops-demo:$Version"
```

Test:

```powershell
.\scripts\smoke-test.ps1 -Url http://localhost:8080/healthz -ExpectedVersion 1.0.0
```

Publish:

```powershell
docker login
docker push "$DockerUser/auspost-devops-demo:$Version"
```

## Local Kubernetes

Enable Kubernetes in Docker Desktop, then:

```powershell
kubectl config use-context docker-desktop
kubectl apply -k k8s/overlays/local
kubectl -n auspost-demo set image deployment/auspost-devops-demo app="$DockerUser/auspost-devops-demo:$Version"
kubectl -n auspost-demo rollout status deployment/auspost-devops-demo
kubectl -n auspost-demo get all
```

Test the NodePort:

```powershell
.\scripts\smoke-test.ps1 -Url http://localhost:30080/healthz -ExpectedVersion $Version
```

If Docker Desktop does not expose the NodePort on your installation, use port-forwarding:

```powershell
kubectl -n auspost-demo port-forward service/auspost-devops-demo 8080:80
```

Then browse `http://localhost:8080/healthz`.

## AWS with Terraform

The infrastructure is now managed through a dedicated Terraform GitHub Actions pipeline. There is one local bootstrap step because the remote S3 backend and the GitHub Terraform OIDC role must exist before GitHub can run Terraform.

### One-time bootstrap

```powershell
cd terraform/bootstrap
Copy-Item terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your GitHub owner/repo and a globally unique S3 bucket name.
terraform init
terraform fmt -check
terraform validate
terraform plan -out bootstrap.tfplan
terraform apply bootstrap.tfplan
terraform output state_bucket_name
terraform output terraform_role_arn
cd ../..
```

Create these GitHub settings from the outputs:

- Repository variable `TF_STATE_BUCKET`
- Repository secret `AWS_TERRAFORM_ROLE_ARN`

After this bootstrap, normal infrastructure changes should be made through pull requests under `terraform/**`. The Terraform workflow plans changes on pull requests and applies them only after merge/push to `main`.

The main state is stored in S3 at:

```text
auspost-devops-demo/terraform.tfstate
```

The backend enables native S3 state locking with `use_lockfile = true`, and the bootstrap bucket has versioning, encryption and public-access blocking enabled.

Once the Terraform workflow creates EKS, get its application deployment role output from the successful workflow logs or locally using the same backend:

```powershell
cd terraform/aws
Copy-Item backend.hcl.example backend.hcl
# Put your bootstrap S3 bucket name in backend.hcl.
terraform init -reconfigure -backend-config=backend.hcl
terraform output github_actions_role_arn
cd ../..
```

Put that ARN in GitHub secret `AWS_DEPLOY_ROLE_ARN`.

## GitHub Actions configuration

Repository secrets:

- `DOCKERHUB_USERNAME` - Docker Hub username
- `DOCKERHUB_TOKEN` - Docker Hub access token (not account password)
- `AWS_TERRAFORM_ROLE_ARN` - one-time bootstrap output used only by Terraform CI/CD
- `AWS_DEPLOY_ROLE_ARN` - main Terraform output used only by application CD

Repository variables:

- `TF_STATE_BUCKET` - one-time bootstrap S3 bucket output

You do **not** need to manually set `github_repository` for the normal GitHub Terraform run. The workflow exports `TF_VAR_github_repository=${{ github.repository }}` automatically, so the deployment role trust policy is scoped to the current repository.

## Pipeline behaviour

### Pull request

1. Checkout.
2. Install Python dependencies.
3. Ruff lint.
4. pytest unit tests.
5. Bandit static security scan.
6. pip-audit dependency scan.
7. Build Docker image.
8. Trivy scan; HIGH/CRITICAL vulnerabilities fail the job.
9. Nothing is deployed.

### Merge/push to `main`

CI repeats all validation, then publishes:

- `DOCKERHUB_USERNAME/auspost-devops-demo:sha-<first-12-commit-chars>`
- `DOCKERHUB_USERNAME/auspost-devops-demo:latest`

On successful CI, CD:

1. Assumes AWS role with GitHub OIDC.
2. Configures kubeconfig for EKS.
3. Applies Kubernetes manifests.
4. Applies manifests with the immutable image tag; the image itself contains the matching `APP_VERSION`.
5. Waits for rollout completion.
6. Rolls back automatically if rollout fails.
7. Runs a disposable curl pod to verify `/healthz` returns the exact deployed version.
8. Displays rollout history.

## Manual rollback demonstration

```powershell
kubectl -n auspost-demo rollout history deployment/auspost-devops-demo
kubectl -n auspost-demo rollout undo deployment/auspost-devops-demo
kubectl -n auspost-demo rollout status deployment/auspost-devops-demo
```

A good assessment demonstration is to intentionally deploy a bad image tag, show the rollout failing, then show the rollback mechanism restoring the previous ReplicaSet.

## Branching and merging strategy

Use trunk-based development with short-lived feature branches:

```text
main
 |
 +-- feature/health-message
 +-- fix/readiness-probe
 +-- chore/dependency-update
```

Recommended controls:

- protect `main`
- no direct pushes to `main`
- pull request required
- at least one reviewer
- CI checks required before merge
- squash merge to keep a clean history
- Conventional Commits (`feat:`, `fix:`, `chore:`)
- immutable container tags based on Git SHA
- semantic Git tags (`v1.0.0`) for release milestones
- promote the same immutable artifact rather than rebuilding per environment

## Security choices to discuss

- application runs as a non-root UID
- Linux capabilities are dropped
- privilege escalation is disabled
- root filesystem is read-only
- Kubernetes service-account token is not mounted because the app does not call the Kubernetes API
- resource limits reduce noisy-neighbour/DoS impact
- NetworkPolicy limits traffic
- Docker Hub password is not committed; use an access token in GitHub Secrets
- AWS credentials are not stored in GitHub; OIDC issues short-lived credentials
- EKS deployment role receives namespace-scoped edit access rather than cluster-admin
- CI blocks HIGH/CRITICAL container vulnerabilities
- control-plane audit/API/authenticator logs are enabled in EKS

## TLS bonus

The supplied base assessment works over HTTP so it can be reproduced locally without owning a domain. For the bonus, the production design should add TLS at the ingress/load-balancer layer using a certificate issued for the chosen domain (for example ACM + an AWS ingress controller, or cert-manager + ingress-nginx). Do not commit private keys. Explain that in a real production design you would enforce HTTPS-only redirects and encrypt any service-to-service traffic that crosses a trust boundary.

## Cleanup

Local:

```powershell
kubectl delete -k k8s/overlays/local
```

AWS:

```powershell
kubectl delete -k k8s/overlays/aws
cd terraform/aws
terraform destroy
```

Delete the Kubernetes LoadBalancer before Terraform destroy so AWS is not left with an orphaned load balancer.

---

## Terraform CI/CD and remote state

Infrastructure has its own GitHub Actions workflow: `.github/workflows/terraform.yml`.

The workflow is isolated from application delivery using GitHub path filters:

```text
terraform/** only
    -> Terraform workflow
    -> fmt -> init -> validate -> plan
    -> PR: stop after plan
    -> main: apply reviewed plan

all non-Terraform changes
    -> application CI
    -> test -> scan -> Docker build -> Trivy -> Docker Hub
    -> application CD -> EKS
```

`.github/workflows/ci.yml` uses `paths-ignore: terraform/**`, so a Terraform-only change does not rebuild or deploy the Python application. If one commit changes both application and Terraform code, both independent workflows run, which is intentional.

### Why there is a bootstrap stack

Terraform cannot store its state in an S3 bucket until the bucket exists. `terraform/bootstrap` is therefore run once from an authorised workstation to create:

1. the private/versioned/encrypted Terraform S3 state bucket;
2. the GitHub OIDC provider;
3. the IAM role used by the Terraform GitHub Actions workflow.

After bootstrap, configure GitHub with:

```text
Repository variable:
TF_STATE_BUCKET=<terraform output state_bucket_name>

Repository secret:
AWS_TERRAFORM_ROLE_ARN=<terraform output terraform_role_arn>
```

The main infrastructure stack has an S3 backend with:

```hcl
use_lockfile = true
```

so Terraform uses native S3 state locking. Bucket versioning provides state recovery history and server-side encryption protects state at rest.

The application CD role is separate from the Terraform role. Terraform needs infrastructure-provisioning permissions, while application CD is limited to describing EKS at AWS IAM level and editing only the `auspost-demo` namespace through EKS access policies. This keeps infrastructure and application deployment as separate trust boundaries.
