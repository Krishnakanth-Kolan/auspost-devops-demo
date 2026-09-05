data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = var.project_name
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  tags = {
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Environment = "assessment"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = "${local.name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [cidrsubnet(var.vpc_cidr, 4, 0), cidrsubnet(var.vpc_cidr, 4, 1)]
  public_subnets  = [cidrsubnet(var.vpc_cidr, 4, 8), cidrsubnet(var.vpc_cidr, 4, 9)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.25.0"

  name               = local.name
  kubernetes_version = var.kubernetes_version

  endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  addons = {
    coredns = {}
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  access_entries = var.github_repository != "" ? {
    github_deploy = {
      principal_arn = aws_iam_role.github_deploy[0].arn
      policy_associations = {
        namespace_edit = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
          access_scope = {
            type       = "namespace"
            namespaces = ["auspost-demo"]
          }
        }
      }
    }
  } : {}

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      desired_size   = var.node_desired_size
      max_size       = var.node_max_size

      capacity_type = "ON_DEMAND"

      labels = {
        workload = "general"
      }

      update_config = {
        max_unavailable_percentage = 33
      }
    }
  }
}

resource "aws_route53_record" "app" {
  count = var.domain_name != "" && var.hosted_zone_id != "" && var.load_balancer_hostname != "" ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "CNAME"
  ttl     = 60
  records = [var.load_balancer_hostname]
}

resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = "auspost-demo"
    labels = {
      "app.kubernetes.io/part-of" = "auspost-devops-assessment"
    }
  }

  depends_on = [module.eks]
}
