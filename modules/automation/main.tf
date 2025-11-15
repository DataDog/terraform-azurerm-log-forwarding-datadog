# Data sources
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "resource_group" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

# Storage Account (optional - created if not provided)
resource "azurerm_storage_account" "storage" {
  count = var.storage_connection_string == null ? 1 : 0

  name                       = "lfostorage${var.control_plane_id}"
  resource_group_name        = azurerm_resource_group.resource_group.name
  location                   = azurerm_resource_group.resource_group.location
  account_tier               = "Standard"
  account_replication_type   = var.storage_account_replication_type
  min_tls_version            = "TLS1_2"
  https_traffic_only_enabled = true

  tags = var.tags
}

# Local to get the connection string from either the created storage account or the provided one
locals {
  storage_connection_string = var.storage_connection_string != null ? var.storage_connection_string : azurerm_storage_account.storage[0].primary_connection_string
}
