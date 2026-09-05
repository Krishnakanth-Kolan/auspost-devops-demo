# Terraform Bootstrap

This is a **one-time bootstrap stack**. It exists because Terraform cannot use an S3 backend until that backend bucket already exists.

It creates:

- a private S3 bucket for Terraform state;
- bucket versioning for state recovery;
- server-side encryption;
- public-access blocking;
- a GitHub Actions OIDC provider;
- a GitHub Actions Terraform IAM role trusted only by this repository's pull requests and `main` branch.

The normal `terraform/aws` stack then uses this bucket as its remote backend and uses S3 native state locking (`use_lockfile = true`).

## One-time setup

Authenticate locally to the AWS account with an identity allowed to create S3 and IAM resources, then:

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform fmt -check
terraform validate
terraform plan -out bootstrap.tfplan
terraform apply bootstrap.tfplan
```

Read the outputs:

```bash
terraform output state_bucket_name
terraform output terraform_role_arn
```

Configure the GitHub repository with:

- Repository variable `TF_STATE_BUCKET` = `state_bucket_name`
- Repository secret `AWS_TERRAFORM_ROLE_ARN` = `terraform_role_arn`

The bootstrap stack is intentionally not run by the normal Terraform workflow. Keep its local state protected because it contains ownership of the remote-state bucket and Terraform execution role. For a larger production platform, this bootstrap would typically live in a separately controlled foundational infrastructure account/repository.
