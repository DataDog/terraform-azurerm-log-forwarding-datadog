# Unless explicitly stated otherwise all files in this repository are licensed under the Apache-2 License.

# This product includes software developed at Datadog (https://www.datadoghq.com/) Copyright 2025 Datadog, Inc.

terraform {
  required_version = ">= 1.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

locals {
  control_plane_id = var.control_plane_id != null && var.control_plane_id != "" ? var.control_plane_id : random_string.control_plane_id[0].result

  monitored_subscriptions = distinct([
    for rg in values(var.monitored_resource_groups) : rg.subscription_id
  ])

  resource_names = {
    storage_account          = "lfostorage${local.control_plane_id}"
    resources_task           = "resources-task-${local.control_plane_id}"
    scaling_task             = "scaling-task-${local.control_plane_id}"
    diagnostic_settings_task = "diagnostic-settings-task-${local.control_plane_id}"
    cache_container          = "control-plane-cache"
    control_plane_env        = "control-plane-env-${local.control_plane_id}"
    deployer_env             = "dd-log-forwarder-env-${local.control_plane_id}"
    deployer_task            = "deployer-task-${local.control_plane_id}"
  }

  deployer_image_url = "${var.image_registry}/deployer-caj:${var.deployer_image_tag}"

  storage_connection_string = "DefaultEndpointsProtocol=https;AccountName=${azurerm_storage_account.control_plane.name};EndpointSuffix=${azurerm_storage_account.control_plane.primary_blob_endpoint != "" ? "core.windows.net" : ""};AccountKey=${azurerm_storage_account.control_plane.primary_access_key}"
}

resource "random_string" "control_plane_id" {
  count   = var.control_plane_id == null || var.control_plane_id == "" ? 1 : 0
  length  = 12
  special = false
  upper   = false
  numeric = true
  lower   = true
}

resource "azurerm_resource_group" "resource_group" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

resource "azurerm_storage_account" "control_plane" {
  name                            = local.resource_names.storage_account
  resource_group_name             = azurerm_resource_group.resource_group.name
  location                        = azurerm_resource_group.resource_group.location
  account_tier                    = "Standard"
  account_replication_type        = var.storage_replication_type
  account_kind                    = "StorageV2"
  access_tier                     = "Hot"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  blob_properties {
    change_feed_enabled = false
    versioning_enabled  = false
  }

  tags = var.tags
}

resource "azurerm_storage_container" "cache" {
  name                  = local.resource_names.cache_container
  storage_account_id    = azurerm_storage_account.control_plane.id
  container_access_type = "private"

  depends_on = [azurerm_storage_account.control_plane]
}

resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.control_plane.id

  rule {
    name    = "delete-old-cache-blobs"
    enabled = true

    filters {
      prefix_match = ["${local.resource_names.cache_container}/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = var.cache_retention_days
      }
    }
  }
}

# =====================================================
# Control Plane Container App Infrastructure
# =====================================================

resource "azurerm_container_app_environment" "control_plane_env" {
  name                = local.resource_names.control_plane_env
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  tags = var.tags
}

resource "azurerm_container_app_job" "resources_task" {
  name                         = local.resource_names.resources_task
  location                     = azurerm_resource_group.resource_group.location
  resource_group_name          = azurerm_resource_group.resource_group.name
  container_app_environment_id = azurerm_container_app_environment.control_plane_env.id

  replica_timeout_in_seconds = 300
  replica_retry_limit        = 0

  schedule_trigger_config {
    cron_expression          = "*/5 * * * *"
    parallelism              = 1
    replica_completion_count = 1
  }

  template {
    container {
      name   = "resources-task"
      image  = "${var.image_registry}/resources-task:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name        = "AzureWebJobsStorage"
        secret_name = "connection-string"
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
        name  = "DD_TELEMETRY"
        value = tostring(var.datadog_telemetry)
      }
      env {
        name  = "CONTROL_PLANE_ID"
        value = local.control_plane_id
      }
      env {
        name  = "CONTROL_PLANE_REGION"
        value = var.location
      }
      env {
        name  = "SUBSCRIPTION_ID"
        value = data.azurerm_subscription.current.subscription_id
      }
      env {
        name  = "LOG_LEVEL"
        value = var.log_level
      }
      env {
        name  = "MONITORED_SUBSCRIPTIONS"
        value = jsonencode(local.monitored_subscriptions)
      }
      env {
        name  = "RESOURCE_TAG_FILTERS"
        value = var.resource_tag_filters
      }
    }
  }

  secret {
    name  = "connection-string"
    value = local.storage_connection_string
  }
  secret {
    name  = "dd-api-key"
    value = var.datadog_api_key
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

  depends_on = [
    azurerm_container_app_environment.control_plane_env,
    azurerm_storage_account.control_plane
  ]
}

resource "azurerm_container_app_job" "scaling_task" {
  name                         = local.resource_names.scaling_task
  location                     = azurerm_resource_group.resource_group.location
  resource_group_name          = azurerm_resource_group.resource_group.name
  container_app_environment_id = azurerm_container_app_environment.control_plane_env.id

  replica_timeout_in_seconds = 600
  replica_retry_limit        = 0

  schedule_trigger_config {
    cron_expression          = "*/5 * * * *"
    parallelism              = 1
    replica_completion_count = 1
  }

  template {
    container {
      name   = "scaling-task"
      image  = "${var.image_registry}/scaling-task:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name        = "AzureWebJobsStorage"
        secret_name = "connection-string"
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
        name  = "DD_TELEMETRY"
        value = tostring(var.datadog_telemetry)
      }
      env {
        name  = "CONTROL_PLANE_ID"
        value = local.control_plane_id
      }
      env {
        name  = "CONTROL_PLANE_REGION"
        value = var.location
      }
      env {
        name  = "SUBSCRIPTION_ID"
        value = data.azurerm_subscription.current.subscription_id
      }
      env {
        name  = "LOG_LEVEL"
        value = var.log_level
      }
      env {
        name  = "RESOURCE_GROUP"
        value = var.resource_group_name
      }
      env {
        name  = "FORWARDER_IMAGE"
        value = var.forwarder_image
      }
      env {
        name  = "PII_SCRUBBER_RULES"
        value = var.pii_scrubber_rules
      }
    }
  }

  secret {
    name  = "connection-string"
    value = local.storage_connection_string
  }
  secret {
    name  = "dd-api-key"
    value = var.datadog_api_key
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

  depends_on = [
    azurerm_container_app_environment.control_plane_env,
    azurerm_storage_account.control_plane
  ]
}

resource "azurerm_container_app_job" "diagnostic_settings_task" {
  name                         = local.resource_names.diagnostic_settings_task
  location                     = azurerm_resource_group.resource_group.location
  resource_group_name          = azurerm_resource_group.resource_group.name
  container_app_environment_id = azurerm_container_app_environment.control_plane_env.id

  replica_timeout_in_seconds = 300
  replica_retry_limit        = 0

  schedule_trigger_config {
    cron_expression          = "*/5 * * * *"
    parallelism              = 1
    replica_completion_count = 1
  }

  template {
    container {
      name   = "diagnostic-settings-task"
      image  = "${var.image_registry}/diagnostic-settings-task:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name        = "AzureWebJobsStorage"
        secret_name = "connection-string"
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
        name  = "DD_TELEMETRY"
        value = tostring(var.datadog_telemetry)
      }
      env {
        name  = "CONTROL_PLANE_ID"
        value = local.control_plane_id
      }
      env {
        name  = "CONTROL_PLANE_REGION"
        value = var.location
      }
      env {
        name  = "SUBSCRIPTION_ID"
        value = data.azurerm_subscription.current.subscription_id
      }
      env {
        name  = "LOG_LEVEL"
        value = var.log_level
      }
      env {
        name  = "RESOURCE_GROUP"
        value = var.resource_group_name
      }
    }
  }

  secret {
    name  = "connection-string"
    value = local.storage_connection_string
  }
  secret {
    name  = "dd-api-key"
    value = var.datadog_api_key
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

  depends_on = [
    azurerm_container_app_environment.control_plane_env,
    azurerm_storage_account.control_plane
  ]
}

# =====================================================
# Deployer Container App Infrastructure
# =====================================================

resource "azurerm_container_app_environment" "deployer_env" {
  name                = local.resource_names.deployer_env
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  tags = var.tags
}

resource "azurerm_container_app_job" "deployer_task" {
  name                         = local.resource_names.deployer_task
  location                     = azurerm_resource_group.resource_group.location
  resource_group_name          = azurerm_resource_group.resource_group.name
  container_app_environment_id = azurerm_container_app_environment.deployer_env.id

  replica_timeout_in_seconds = 1800
  replica_retry_limit        = 1

  schedule_trigger_config {
    cron_expression          = var.deployer_schedule
    parallelism              = 1
    replica_completion_count = 1
  }

  template {
    container {
      name   = local.resource_names.deployer_task
      image  = local.deployer_image_url
      cpu    = 0.5
      memory = "1Gi"

      env {
        name        = "AzureWebJobsStorage"
        secret_name = "connection-string"
      }
      env {
        name  = "SUBSCRIPTION_ID"
        value = data.azurerm_subscription.current.subscription_id
      }
      env {
        name  = "RESOURCE_GROUP"
        value = var.resource_group_name
      }
      env {
        name  = "CONTROL_PLANE_ID"
        value = local.control_plane_id
      }
      env {
        name  = "CONTROL_PLANE_REGION"
        value = var.location
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
        name  = "DD_TELEMETRY"
        value = tostring(var.datadog_telemetry)
      }
      env {
        name  = "STORAGE_ACCOUNT_URL"
        value = var.storage_account_url
      }
      env {
        name  = "LOG_LEVEL"
        value = var.log_level
      }
    }
  }

  secret {
    name  = "connection-string"
    value = local.storage_connection_string
  }
  secret {
    name  = "dd-api-key"
    value = var.datadog_api_key
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

  depends_on = [
    azurerm_container_app_environment.deployer_env,
    azurerm_storage_account.control_plane
  ]
}

# =====================================================
# Role Assignments for Control Plane Task Identities
# =====================================================

resource "azurerm_role_assignment" "resources_task_monitoring_reader" {
  for_each = toset(local.monitored_subscriptions)

  scope                            = "/subscriptions/${each.value}"
  role_definition_id               = data.azurerm_role_definition.monitoring_reader.id
  principal_id                     = azurerm_container_app_job.resources_task.identity[0].principal_id
  description                      = "ddlfo${local.control_plane_id}"
  skip_service_principal_aad_check = true

  depends_on = [azurerm_container_app_job.resources_task]
}

resource "azurerm_role_assignment" "scaling_task_contributor" {
  for_each = var.monitored_resource_groups

  scope                            = "/subscriptions/${each.value.subscription_id}/resourceGroups/${each.value.resource_group_name}"
  role_definition_id               = data.azurerm_role_definition.contributor.id
  principal_id                     = azurerm_container_app_job.scaling_task.identity[0].principal_id
  description                      = "ddlfo${local.control_plane_id}"
  skip_service_principal_aad_check = true

  depends_on = [azurerm_container_app_job.scaling_task]
}

resource "azurerm_role_assignment" "diagnostic_settings_task_monitoring_contributor" {
  for_each = toset(local.monitored_subscriptions)

  scope                            = "/subscriptions/${each.value}"
  role_definition_id               = data.azurerm_role_definition.monitoring_contributor.id
  principal_id                     = azurerm_container_app_job.diagnostic_settings_task.identity[0].principal_id
  description                      = "ddlfo${local.control_plane_id}"
  skip_service_principal_aad_check = true

  depends_on = [azurerm_container_app_job.diagnostic_settings_task]
}

resource "azurerm_role_assignment" "diagnostic_settings_task_reader_data_access" {
  for_each = var.monitored_resource_groups

  scope                            = "/subscriptions/${each.value.subscription_id}/resourceGroups/${each.value.resource_group_name}"
  role_definition_id               = data.azurerm_role_definition.reader_data_access.id
  principal_id                     = azurerm_container_app_job.diagnostic_settings_task.identity[0].principal_id
  description                      = "ddlfo${local.control_plane_id}"
  skip_service_principal_aad_check = true

  depends_on = [azurerm_container_app_job.diagnostic_settings_task]
}

# =====================================================
# Role Assignments for Deployer Task Identity
# =====================================================

resource "azurerm_role_assignment" "deployer_task_website_contributor" {
  scope                            = azurerm_resource_group.resource_group.id
  role_definition_id               = data.azurerm_role_definition.website_contributor.id
  principal_id                     = azurerm_container_app_job.deployer_task.identity[0].principal_id
  description                      = "ddlfo${local.control_plane_id}"
  skip_service_principal_aad_check = true

  depends_on = [azurerm_container_app_job.deployer_task]
}

resource "azurerm_role_assignment" "deployer_task_monitoring_contributor" {
  for_each = toset(local.monitored_subscriptions)

  scope                            = "/subscriptions/${each.value}"
  role_definition_id               = data.azurerm_role_definition.monitoring_contributor.id
  principal_id                     = azurerm_container_app_job.deployer_task.identity[0].principal_id
  description                      = "ddlfo${local.control_plane_id}"
  skip_service_principal_aad_check = true

  depends_on = [azurerm_container_app_job.deployer_task]
}

resource "azurerm_role_assignment" "deployer_task_contributor" {
  for_each = var.monitored_resource_groups

  scope                            = "/subscriptions/${each.value.subscription_id}/resourceGroups/${each.value.resource_group_name}"
  role_definition_id               = data.azurerm_role_definition.contributor.id
  principal_id                     = azurerm_container_app_job.deployer_task.identity[0].principal_id
  description                      = "ddlfo${local.control_plane_id}"
  skip_service_principal_aad_check = true

  depends_on = [azurerm_container_app_job.deployer_task]
}

# =====================================================
# Removed resources (migrated from function apps to container app jobs)
# Existing deployments: terraform plan will show these as destroy.
# =====================================================

removed {
  from = azurerm_service_plan.control_plane
  lifecycle { destroy = true }
}

removed {
  from = azurerm_storage_share.function_content
  lifecycle { destroy = true }
}

removed {
  from = azurerm_linux_function_app.resources_task
  lifecycle { destroy = true }
}

removed {
  from = azurerm_linux_function_app.scaling_task
  lifecycle { destroy = true }
}

removed {
  from = azurerm_linux_function_app.diagnostic_settings_task
  lifecycle { destroy = true }
}
