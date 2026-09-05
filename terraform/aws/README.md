# AWS Terraform Application Infrastructure

This stack provisions the AWS infrastructure requested by the assessment:

- VPC across two Availability Zones
- public and private subnets
- NAT gateway
- EKS control plane with control-plane logging
- EKS managed node group in private subnets
- GitHub Actions deployment role with EKS namespace-scoped access
- optional Route53 DNS record for the Kubernetes load balancer

## Remote state

The stack uses the S3 backend defined in `backend.tf`:

```hcl
terraform {
  backend "s3" {
    key          = "auspost-devops-demo/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
```

The bucket name and region are supplied during `terraform init`. The bucket is created once by `terraform/bootstrap` and has versioning, encryption and public-access blocking enabled.

`use_lockfile = true` enables Terraform's native S3 state locking. Concurrent Terraform writers therefore cannot safely update the same state at the same time.

## One-time bootstrap

Before the Terraform GitHub Actions workflow can run for the first time, create its backend and OIDC role:

```bash
cd ../bootstrap
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out bootstrap.tfplan
terraform apply bootstrap.tfplan
```

Then add the bootstrap outputs to GitHub:

- `TF_STATE_BUCKET` as a repository **variable**
- `AWS_TERRAFORM_ROLE_ARN` as a repository **secret**

See `terraform/bootstrap/README.md` for full details.

## Automated workflow

`.github/workflows/terraform.yml` runs only when a file below `terraform/**` changes:

- Pull request to `main`: `fmt` → remote-state `init` → `validate` → `plan`; no apply.
- Push/merge to `main`: the same validation and plan steps, followed by `terraform apply` using that exact plan.

The workflow authenticates to AWS with GitHub OIDC and temporary credentials.

## Local plan/apply using the same S3 backend

Copy the backend example and populate only non-secret backend values:

```bash
cp backend.hcl.example backend.hcl
terraform init -reconfigure -backend-config=backend.hcl
terraform fmt -check -recursive
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```

If you already have an existing **local** `terraform.tfstate` from an earlier version of this lab, migrate it to S3 instead of discarding it:

```bash
terraform init -migrate-state -backend-config=backend.hcl
```

Review the migration prompt carefully before confirming.

## Application load balancer and DNS

After EKS exists, application CD deploys `k8s/overlays/aws`. Obtain the load-balancer hostname with:

```bash
kubectl -n auspost-demo get service auspost-devops-demo
kubectl -n auspost-demo get service auspost-devops-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

If you own a Route53-managed domain, set `domain_name`, `hosted_zone_id`, and `load_balancer_hostname` in your Terraform variables and commit the Terraform change. The Terraform workflow will create the DNS CNAME after merge to `main`.

## Destroy

Remove the Kubernetes Service first so AWS can delete its load balancer, then destroy the Terraform-managed infrastructure from an authorised local session or a deliberately added destroy workflow:

```bash
kubectl delete -k ../../k8s/overlays/aws
terraform destroy
```

Destruction is intentionally **not** part of the normal GitHub Actions workflow.

> EKS, EC2, NAT Gateway and load balancers incur AWS charges. Destroy the lab when finished.
