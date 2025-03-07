// The name of the resource group
variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  default     = "myResourceGroup"
}

// The location of the resource group
variable "location" {
  description = "The location of the resource group"
  type        = string
  default     = "polandcentral"
}

// The name of the AKS cluster
variable "cluster_name" {
  description = "The name of the AKS cluster"
  type        = string
  default     = "myAKSCluster"
}

// The DNS prefix for the AKS cluster
variable "dns_prefix" {
  description = "The DNS prefix for the AKS cluster"
  type        = string
  default     = "myaks"
}

// The number of nodes in the default node pool
variable "node_count" {
  description = "The number of nodes in the default node pool"
  type        = number
  default     = 8
}

// The number of nodes in the additional node pool
variable "additional_node_count" {
  description = "The number of nodes in the additional node pool"
  type        = number
  default     = 15
}

// The number of master nodes in the default node pool
variable "master_node_count" {
  description = "The number of master nodes in the default node pool"
  type        = number
  default     = 3
}

// The number of worker nodes in the additional node pool
variable "worker_node_count" {
  description = "The number of worker nodes in the additional node pool"
  type        = number
  default     = 5
}

// The size of the VMs in the default node pool
variable "vm_size" {
  description = "The size of the VMs in the default node pool"
  type        = string
  default     = "Standard_DS2_v2"
}

// The number of additional node pools
variable "additional_node_pool_count" {
  description = "The number of additional node pools"
  type        = number
  default     = 0
}

// The size of the VMs in the additional node pool
variable "additional_vm_size" {
  description = "The size of the VMs in the additional node pool"
  type        = string
  default     = "Standard_DS2_v2"
}

// The application name
variable "app" {
  description = "The application name"
  type        = string
  default     = "myApp"
}

// The creator of the resources
variable "creator" {
  description = "The creator of the resources"
  type        = string
  default     = "hufhendr"
}

// The unit responsible for the resources
variable "unit" {
  description = "The unit responsible for the resources"
  type        = string
  default     = "EBS"
}

// The environment (e.g., dev, prod)
variable "env" {
  description = "The environment (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

// The subscription ID for Azure
variable "subscription_id" {
  description = "The subscription ID for Azure"
  type        = string
  default     = "d4d56231-1034-49c8-9710-d1d43c837ac9"
}

// The version of Kubernetes for the AKS cluster
variable "kubernetes_version" {
  description = "The version of Kubernetes for the AKS cluster"
  type        = string
  default     = "1.31.4"
}
