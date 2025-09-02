#   ***************************************
#   Deployment of EKS for a regular project
#   begin     : Wed 30 Jul 2025
#   copyright : (c) 2025 Václav Dvorský
#   email     : hufhendr@gmail.com
#   $Id: main.tf, v1.00 31/07/2025
#   ***************************************

#   --------------------------------------------------------------------
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public Licence as published by
#   the Free Software Foundation; either version 2 of the Licence, or
#   (at your option) any later version.
#   --------------------------------------------------------------------

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      App     = var.app
      Creator = var.creator
      Unit    = var.unit
      Env     = var.env
    }
  }
}

data "aws_availability_zones" "available" {
  # Exclude local zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

locals {
  name = "ex-${basename(path.cwd)}"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)
}

# EKS Module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name                   = local.name
  kubernetes_version     = var.kubernetes_version
  endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
}

module "disabled_eks" {
  source = "terraform-aws-modules/eks/aws"

  create = false
}


# Supporting Resources
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = local.name
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 52)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

# Route53 Record for EKS API
resource "aws_route53_record" "eks_api" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "api.${var.domain_eks}.${var.env}.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [replace(module.eks.cluster_endpoint, "https://", "")]
}

# Prepare Helm provider
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# Deploy Ingress NGINX Controller
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.13.0"
}

# Deploy Cert Manager
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.18.2"
  set = [
    {
      name  = "installCRDs"
      value = "true"
    }
  ]
}
