
variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.32"
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
