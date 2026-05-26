variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "Dev resource group name from calstate infra"
  type        = string
  default     = "Grouper-Dev"
}

variable "aks_cluster_name" {
  description = "Dev AKS cluster name from calstate infra"
  type        = string
  default     = "aks-grouper-dev-cluster"
}

variable "vnet_name" {
  description = "Dev VNet name from calstate infra"
  type        = string
  default     = "grouper-dev-tf-vnet"
}

variable "alb_subnet_cidr" {
  description = "CIDR for the new ALB subnet — must not overlap existing calstate subnets"
  type        = string
  default     = "10.247.81.160/27"
}

variable "name_prefix" {
  description = "Prefix for ALB resources"
  type        = string
  default     = "grouper-dev"
}
