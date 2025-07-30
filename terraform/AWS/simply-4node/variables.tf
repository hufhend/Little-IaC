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

// VPC configuration
variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_name" {
  description = "The name of the VPC"
  type        = string
  default     = "main-vpc"
}

// Subnet configuration
variable "subnet_cidr_block" {
  description = "The CIDR block for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_name" {
  description = "The name of the subnet"
  type        = string
  default     = "main-subnet"
}

// Internet gateway configuration
variable "igw_name" {
  description = "The name of the internet gateway"
  type        = string
  default     = "main-igw"
}

// Route table configuration
variable "route_table_name" {
  description = "The name of the route table"
  type        = string
  default     = "main-route-table"
}

// Security group configuration
variable "security_group_cidr_ingress" {
  description = "The CIDR block for ingress rules"
  type        = string
  default     = "0.0.0.0/0"
}

variable "security_group_cidr_egress" {
  description = "The CIDR block for egress rules"
  type        = string
  default     = "0.0.0.0/0"
}

variable "security_group_name" {
  description = "The name of the security group"
  type        = string
  default     = "main-security-group"
}

variable "security_group_ports" {
  description = "The list of ports for the security group"
  type        = list(number)
  default     = [80, 443, 22, 6443]
}

// Instance count configuration
variable "instance_count" {
  description = "The number of instances to create"
  type        = number
  default     = 4
}

// Key pair configuration
variable "key_name" {
  description = "The name of the key pair"
  type        = string
  default     = "my-key"
}

variable "public_key_path" {
  description = "The path to the public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

// Tag configuration
variable "app" {
  description = "The application name"
  type        = string
  default     = "K8s cluster"
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
