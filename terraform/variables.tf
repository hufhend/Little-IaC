// Variable definitions for the Terraform configuration
variable "username" {
  description = "The name of the user to create"
  type        = string
  default     = "hufhendr"
}

// AWS region configuration
variable "region" {
  description = "The AWS region to deploy in"
  type        = string
  default     = "eu-central-1"
}

// AMI configuration
variable "ami" {
  description = "The AMI ID to use for the instance"
  type        = string
  default     = "ami-07eef52105e8a2059"
}

// Instance type configuration
variable "instance_type" {
  description = "The instance type to use"
  type        = string
  default     = "t3.small"
}
