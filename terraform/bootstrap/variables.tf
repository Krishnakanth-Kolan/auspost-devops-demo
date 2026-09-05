variable "aws_region" {
  description = "AWS region for the Terraform remote-state bucket."
  type        = string
  default     = "ap-southeast-2"
}

variable "project_name" {
  description = "Project identifier used for bootstrap resource names."
  type        = string
  default     = "auspost-devops-demo"
}

variable "github_repository" {
  description = "GitHub repository in owner/repo form, for example krish/auspost-devops-demo."
  type        = string
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name used for Terraform remote state."
  type        = string
}
