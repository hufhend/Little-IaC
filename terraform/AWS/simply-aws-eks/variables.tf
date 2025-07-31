
variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.33"
}

variable "domain_name" {
  description = "Route53 main domain"
  type        = string
  default     = "aws.akira.cz"
}

variable "domain_eks" {
  description = "EKS prefix for domain name"
  type        = string
  default     = "eks"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

// Tag configuration
variable "app" {
  description = "The application name"
  type        = string
  default     = "EKS cluster"
}

variable "creator" {
  description = "The creator of the resources"
  type        = string
  default     = "hufhendr"
}

variable "unit" {
  description = "The unit or department"
  type        = string
  default     = "Akira"
}

variable "env" {
  description = "The environment"
  type        = string
  default     = "DEV"
}
