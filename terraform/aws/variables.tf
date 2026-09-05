variable "aws_region" {
  description = "AWS region for the assessment environment."
  type        = string
  default     = "ap-southeast-2"
}

variable "project_name" {
  description = "Short project identifier used for resource names."
  type        = string
  default     = "auspost-devops-demo"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version. Set this to a currently supported EKS version before applying."
  type        = string
  default     = "1.36"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "domain_name" {
  description = "Optional public DNS name for the application, e.g. devops.example.com. Leave blank to skip Route53 record creation."
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID containing domain_name. Required when domain_name is set."
  type        = string
  default     = ""
}

variable "load_balancer_hostname" {
  description = "Kubernetes LoadBalancer hostname. Populate after deploying the Service, then re-run terraform apply to create DNS."
  type        = string
  default     = ""
}

variable "github_repository" {
  description = "GitHub repository in owner/repo form. When set, Terraform creates a GitHub Actions OIDC deployment role scoped to the main branch."
  type        = string
  default     = ""
}
