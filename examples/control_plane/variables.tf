variable "resource_group_name" {
  description = "Name of the resource group where resources will be created"
  type        = string
}

variable "subscription_id" {
  description = "The Azure subscription ID to use for the provider (defaults to first monitored subscription)"
  type        = string
  default     = null
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
  default     = "East US"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Control Plane Configuration
variable "control_plane_id" {
  description = "Unique identifier for the control plane (alphanumeric, lowercase, max 12 chars)"
  type        = string
}

# Datadog Configuration
variable "datadog_api_key" {
  description = "Datadog API key for sending logs and metrics"
  type        = string
  sensitive   = true
}

variable "datadog_site" {
  description = "Datadog site (e.g., datadoghq.com, datadoghq.eu, us3.datadoghq.com)"
  type        = string
  default     = "datadoghq.com"
}

variable "datadog_telemetry" {
  description = "Enable Datadog telemetry"
  type        = bool
  default     = false
}

# Container Configuration
variable "image_registry" {
  description = "Container registry for deployer image"
  type        = string
  default     = "datadoghq.azurecr.io"
}

variable "deployer_image_tag" {
  description = "Tag of the deployer container image"
  type        = string
  default     = "latest"
}

# Logging Configuration
variable "log_level" {
  description = "Log level for the deployer (DEBUG, INFO, WARNING, ERROR, CRITICAL)"
  type        = string
  default     = "INFO"
}

# Storage Configuration
variable "storage_connection_string" {
  description = "Optional storage account connection string. If not provided, a new storage account will be created"
  type        = string
  default     = null
  sensitive   = true
}

# Subscription Configuration
variable "monitored_subscriptions" {
  description = "List of Azure subscription IDs to monitor and deploy forwarders to"
  type        = list(string)
  default     = []
}
