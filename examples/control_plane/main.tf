# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

module "lfo" {
  source = "../../modules/automation"
  providers = {
    azurerm = azurerm
  }

  # Basic Configuration
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  # Control Plane Configuration
  control_plane_id = var.control_plane_id

  # Datadog Configuration
  datadog_api_key   = var.datadog_api_key
  datadog_site      = var.datadog_site
  datadog_telemetry = var.datadog_telemetry

  # Container Configuration
  image_registry     = var.image_registry
  deployer_image_tag = var.deployer_image_tag

  # Logging Configuration
  log_level = var.log_level

  # Storage Configuration (optional)
  storage_connection_string = var.storage_connection_string

  # Subscription Configuration
  monitored_subscriptions = var.monitored_subscriptions
}