terraform {
  backend "azurerm" {
    resource_group_name  = "Grouper"
    storage_account_name = "groupertfstatepoc01"
    container_name       = "terraform"
    key                  = "dcs-apps-alb.tfstate"

    use_azuread_auth     = true
    tenant_id            = "cc590aa0-82d1-4810-8052-03fcd2d71ae5"
    subscription_id      = "91ea5a42-5e9b-4c0c-a766-ea2a2aaa3ace"
    client_id            = "714a21d1-03b1-40a3-9031-bb20ae75c89d"
  }
}