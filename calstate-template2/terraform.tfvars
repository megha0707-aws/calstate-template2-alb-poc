subscription_id    = "f4f3ec7d-9d6f-4752-bdcc-440ed90734fe"

# Dev infra — exact names from calstate infra repo
resource_group_name = "Grouper-Dev"
aks_cluster_name    = "aks-grouper-dev-cluster"
vnet_name           = "grouper-dev-tf-vnet"

# ALB subnet — fits within dev_vnet_cidr 10.247.80.0/23
# Existing subnets use up to 10.247.81.128/25, pick next free /27
alb_subnet_cidr     = "10.247.81.160/27"

name_prefix         = "grouper-dev"
