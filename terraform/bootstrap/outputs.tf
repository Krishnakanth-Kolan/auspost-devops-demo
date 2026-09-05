output "state_bucket_name" {
  description = "Set this value as the GitHub repository variable TF_STATE_BUCKET."
  value       = aws_s3_bucket.terraform_state.id
}

output "terraform_role_arn" {
  description = "Set this value as the GitHub repository secret AWS_TERRAFORM_ROLE_ARN."
  value       = aws_iam_role.github_terraform.arn
}

output "github_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}
