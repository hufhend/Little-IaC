// Define the Azure provider and subscription ID
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

// Create a resource group
resource "azurerm_resource_group" "aks" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    App     = var.app
    Creator = var.creator
    Unit    = var.unit
    Env     = var.env
  }
}

// Create an AKS cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name       = "default"
    node_count = var.master_node_count
    vm_size    = var.vm_size
    tags = {
      Role = "master"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    App     = var.app
    Creator = var.creator
    Unit    = var.unit
    Env     = var.env
  }
}

// Create an additional node pool
resource "azurerm_kubernetes_cluster_node_pool" "additional" {
  count              = var.additional_node_pool_count
  name               = "additional"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size            = var.additional_vm_size
  node_count         = var.additional_node_count
  tags = {
    App     = var.app
    Creator = var.creator
    Unit    = var.unit
    Env     = var.env
    Role    = "worker"
  }
}
