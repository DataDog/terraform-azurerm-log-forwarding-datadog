# Container App Environment
resource "azurerm_container_app_environment" "environment" {
  name                = "dd-log-forwarder-env-${var.control_plane_id}"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  tags = var.tags
}

# Deployer Container App Job
resource "azurerm_container_app_job" "deployer" {
  name                         = "deployer-task-${var.control_plane_id}"
  location                     = azurerm_resource_group.resource_group.location
  resource_group_name          = azurerm_resource_group.resource_group.name
  container_app_environment_id = azurerm_container_app_environment.environment.id

  replica_timeout_in_seconds = 1800
  replica_retry_limit        = 1

  schedule_trigger_config {
    cron_expression          = "*/30 * * * *"
    parallelism              = 1
    replica_completion_count = 1
  }

  template {
    container {
      name   = "deployer"
      image  = "${var.image_registry}/${var.deployer_image_name}:${var.deployer_image_tag}"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name        = "AzureWebJobsStorage"
        secret_name = "storage-connection-string"
      }

      env {
        name  = "SUBSCRIPTION_ID"
        value = data.azurerm_client_config.current.subscription_id
      }

      env {
        name  = "RESOURCE_GROUP"
        value = azurerm_resource_group.resource_group.name
      }

      env {
        name  = "CONTROL_PLANE_ID"
        value = var.control_plane_id
      }

      env {
        name  = "CONTROL_PLANE_REGION"
        value = azurerm_resource_group.resource_group.location
      }

      env {
        name        = "DD_API_KEY"
        secret_name = "datadog-api-key"
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
        value = "https://ddazurelfo.blob.core.windows.net"
      }

      env {
        name  = "LOG_LEVEL"
        value = var.log_level
      }
    }
  }

  secret {
    name  = "storage-connection-string"
    value = local.storage_connection_string
  }

  secret {
    name  = "datadog-api-key"
    value = var.datadog_api_key
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}
