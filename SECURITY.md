# Security Notes

Do not commit:

- Docker Hub tokens
- AWS credentials
- kubeconfig files
- Terraform state or `.tfvars` containing sensitive values
- TLS private keys

If this repository becomes public, use a dedicated Docker Hub access token with minimum scope and rotate it after the assessment if desired.

The GitHub AWS deployment role is intended only for the repository main branch. EKS access is namespace scoped to `auspost-demo`.

## Terraform pipeline security

- Terraform state is stored in a private S3 bucket with versioning, server-side encryption and public-access blocking.
- The main stack enables native S3 state locking with `use_lockfile = true` to prevent concurrent state mutation.
- GitHub Actions assumes the Terraform role through OIDC; long-lived AWS access keys are not stored in the repository.
- The bootstrap OIDC trust is limited to this repository's pull-request context and `main` branch.
- The Terraform provisioning role and application deployment role are deliberately separate because they have different privilege requirements.
- `terraform.tfvars`, local state, plan files and backend-local configuration are excluded from Git where appropriate.
