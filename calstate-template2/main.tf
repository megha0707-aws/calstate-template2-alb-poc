# ============================================================
# Calstate Template 2 — Grouper ALB POC (dev env)
#
# Pre-requisites (calstate infra repo must be applied first):
#   - Resource group: Grouper-Dev
#   - VNet: grouper-dev-tf-vnet
#   - AKS: aks-grouper-dev-cluster (with workload_identity_enabled = true)
#
# Pre-requisites (setup.sh — run once before Stage 2):
#   - Reader role on ALB resource  → assigned to ALB managed identity
#   - Network Contributor on RG    → assigned to ALB managed identity
#
# What Terraform manages:
#   Stage 1: ALB subnet, managed identity, federated credential, ALB resource, association
#   Stage 2: ALB controller (Helm)
#   NOTE: Application pods (Grouper) will be deployed separately via vendor-provided manifests
# ============================================================

# ----- Read existing calstate dev infra -----

data "azurerm_resource_group" "grouper" {
  name = var.resource_group_name
}

data "azurerm_virtual_network" "grouper" {
  name                = var.vnet_name
  resource_group_name = data.azurerm_resource_group.grouper.name
}

data "azurerm_kubernetes_cluster" "grouper" {
  name                = var.aks_cluster_name
  resource_group_name = data.azurerm_resource_group.grouper.name
}

# ----- ALB subnet (new, added into existing calstate dev VNet) -----

# resource "azurerm_subnet" "alb" {
#   name                 = "snet-alb-${var.name_prefix}"
#   resource_group_name  = data.azurerm_resource_group.grouper.name
#   virtual_network_name = data.azurerm_virtual_network.grouper.name
#   address_prefixes     = [var.alb_subnet_cidr]

#   delegation {
#     name = "alb-delegation"
#     service_delegation {
#       name    = "Microsoft.ServiceNetworking/trafficControllers"
#       actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
#     }
#   }
# }
# ----- Expand dev VNet address space to accommodate ALB subnet -----

resource "azurerm_virtual_network" "alb_space" {
  name                = var.vnet_name
  location            = data.azurerm_resource_group.grouper.location
  resource_group_name = data.azurerm_resource_group.grouper.name
  address_space       = ["10.247.80.0/23", "10.247.84.0/27"]
}

# ----- ALB subnet (new, added into existing calstate dev VNet) -----

resource "azurerm_subnet" "alb" {
  name                 = "snet-alb-${var.name_prefix}"
  resource_group_name  = data.azurerm_resource_group.grouper.name
  virtual_network_name = data.azurerm_virtual_network.grouper.name
  address_prefixes     = [var.alb_subnet_cidr]

  depends_on = [azurerm_virtual_network.alb_space]

  delegation {
    name = "alb-delegation"
    service_delegation {
      name    = "Microsoft.ServiceNetworking/trafficControllers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# ----- ALB managed identity + workload identity federation -----

resource "azurerm_user_assigned_identity" "alb" {
  name                = "mi-alb-${var.name_prefix}"
  resource_group_name = data.azurerm_resource_group.grouper.name
  location            = data.azurerm_resource_group.grouper.location
}

resource "azurerm_federated_identity_credential" "alb" {
  name                = "alb-federated"
  resource_group_name = data.azurerm_resource_group.grouper.name
  parent_id           = azurerm_user_assigned_identity.alb.id

  audience = ["api://AzureADTokenExchange"]
  issuer   = data.azurerm_kubernetes_cluster.grouper.oidc_issuer_url
  subject  = "system:serviceaccount:azure-alb-system:alb-controller-sa"
}

# ----- ALB resource + subnet association -----

resource "azapi_resource" "alb" {
  type      = "Microsoft.ServiceNetworking/trafficControllers@2024-05-01-preview"
  name      = "alb-${var.name_prefix}"
  parent_id = data.azurerm_resource_group.grouper.id
  location  = data.azurerm_resource_group.grouper.location

  body = {
    properties = {}
  }
}

resource "azapi_resource" "alb_association" {
  type      = "Microsoft.ServiceNetworking/trafficControllers/associations@2024-05-01-preview"
  name      = "alb-association"
  parent_id = azapi_resource.alb.id
  location  = data.azurerm_resource_group.grouper.location

  body = {
    properties = {
      associationType = "subnets"
      subnet = {
        id = azurerm_subnet.alb.id
      }
    }
  }
}

# ----- ALB controller (Helm) -----

resource "helm_release" "alb_controller" {
  name             = "alb-controller"
  namespace        = "azure-alb-system"
  create_namespace = true

  repository = "oci://mcr.microsoft.com/application-lb/charts"
  chart      = "alb-controller"
  version    = "1.10.28"

  set {
    name  = "albController.podIdentity.clientID"
    value = azurerm_user_assigned_identity.alb.client_id
  }

  depends_on = [
    azurerm_federated_identity_credential.alb,
    azapi_resource.alb,
  ]
}

# ----- TODO: Grouper application -----
# Once the vendor provides the Grouper application manifests, add the following here:
#   - kubernetes_namespace for the app
#   - kubernetes_manifest for Gateway (referencing azapi_resource.alb.id)
#   - kubernetes_manifest for HTTPRoute (pointing to Grouper service)
# The Grouper Deployment/Service manifests can be applied separately via kubectl
# or included as kubernetes_manifest resources in a future Terraform update.
