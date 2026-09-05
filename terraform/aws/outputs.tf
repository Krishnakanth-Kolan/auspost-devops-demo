output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "application_url" {
  value = var.domain_name != "" ? "http://${var.domain_name}" : "DNS record not configured yet"
}

output "github_actions_role_arn" {
  value = var.github_repository != "" ? aws_iam_role.github_deploy[0].arn : "GitHub OIDC role not configured"
}
