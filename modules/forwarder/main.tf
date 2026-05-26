# Unless explicitly stated otherwise all files in this repository are licensed under the Apache-2 License.

# This product includes software developed at Datadog (https://www.datadoghq.com/) Copyright 2025 Datadog, Inc.

terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# ==========================================
# Data Sources
# ==========================================

data "azurerm_resource_group" "current" {
  name = var.resource_group_name
}

data "azurerm_client_config" "current" {}

# ==========================================
# Local Values
# ==========================================

locals {
  create_storage_account = var.existing_storage_account_id == null

  storage_account_name       = local.create_storage_account ? azurerm_storage_account.forwarder_storage[0].name : data.azurerm_storage_account.existing[0].name
  storage_account_id         = local.create_storage_account ? azurerm_storage_account.forwarder_storage[0].id : data.azurerm_storage_account.existing[0].id
  storage_primary_access_key = local.create_storage_account ? azurerm_storage_account.forwarder_storage[0].primary_access_key : data.azurerm_storage_account.existing[0].primary_access_key
  storage_primary_blob_endpoint = local.create_storage_account ? azurerm_storage_account.forwarder_storage[0].primary_blob_endpoint : data.azurerm_storage_account.existing[0].primary_blob_endpoint

  storage_connection_string = "DefaultEndpointsProtocol=https;AccountName=${local.storage_account_name};EndpointSuffix=core.windows.net;AccountKey=${local.storage_primary_access_key}"
}

# ==========================================
# Existing Storage Account Lookup
# ==========================================

data "azurerm_storage_account" "existing" {
  count = local.create_storage_account ? 0 : 1

  name                = regex("[^/]+$", var.existing_storage_account_id)
  resource_group_name = regex("resourceGroups/([^/]+)", var.existing_storage_account_id)[0]
}

# ==========================================
# Storage Account (created only when not using existing)
# ==========================================

resource "azurerm_storage_account" "forwarder_storage" {
  count = local.create_storage_account ? 1 : 0

  name                            = var.storage_account_name
  resource_group_name             = data.azurerm_resource_group.current.name
  location                        = var.location
  account_tier                    = split("_", var.storage_account_sku)[0]
  account_replication_type        = split("_", var.storage_account_sku)[1]
  account_kind                    = "StorageV2"
  access_tier                     = var.storage_access_tier
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  tags = var.tags
}

# ==========================================
# Storage Account Management Policy (created only when not using existing)
# ==========================================

resource "azurerm_storage_management_policy" "forwarder_lifecycle" {
  count = local.create_storage_account ? 1 : 0

  storage_account_id = azurerm_storage_account.forwarder_storage[0].id

  rule {
    name    = "delete-old-blobs"
    enabled = true

    filters {
      blob_types = ["blockBlob", "appendBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = var.storage_account_retention_days
      }
      snapshot {
        delete_after_days_since_creation_greater_than = var.storage_account_retention_days
      }
    }
  }
}

# ==========================================
# Container App Environment
# ==========================================

resource "azurerm_container_app_environment" "forwarder_env" {
  name                = var.environment_name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.current.name

  tags = var.tags
}

# ==========================================
# Container App Job
# ==========================================

resource "azurerm_container_app_job" "forwarder" {
  count = var.forwarder_count

  name                         = var.forwarder_count > 1 ? "${var.job_name}-${count.index}" : var.job_name
  location                     = var.location
  resource_group_name          = data.azurerm_resource_group.current.name
  container_app_environment_id = azurerm_container_app_environment.forwarder_env.id

  replica_timeout_in_seconds = var.replica_timeout_in_seconds
  replica_retry_limit        = var.replica_retry_limit

  schedule_trigger_config {
    cron_expression          = var.schedule_expression
    parallelism              = 1
    replica_completion_count = 1
  }

  template {
    container {
      name   = "datadog-forwarder"
      image  = var.forwarder_image
      cpu    = var.forwarder_cpu
      memory = var.forwarder_memory

      env {
        name        = "AzureWebJobsStorage"
        secret_name = "storage-connection-string"
      }
      env {
        name        = "DD_API_KEY"
        secret_name = "dd-api-key"
      }
      env {
        name  = "DD_SITE"
        value = var.datadog_site
      }
      env {
        name  = "CONTROL_PLANE_ID"
        value = "none"
      }
      env {
        name  = "CONFIG_ID"
        value = "standalone-forwarder-${count.index}"
      }
    }
  }

  secret {
    name  = "storage-connection-string"
    value = local.storage_connection_string
  }

  secret {
    name  = "dd-api-key"
    value = var.datadog_api_key
  }

  tags = var.tags
}
