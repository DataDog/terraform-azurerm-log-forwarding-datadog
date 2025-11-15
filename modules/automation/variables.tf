variable "resource_group_name" {
  description = "Name of the resource group where resources will be created"
  type        = string
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

  validation {
    condition     = can(regex("^[a-z0-9]{1,12}$", var.control_plane_id))
    error_message = "control_plane_id must be alphanumeric, lowercase, and max 12 characters"
  }
}

# Datadog Configuration
variable "datadog_api_key" {
  description = "Datadog API key for sending logs and metrics"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.datadog_api_key) == 32
    error_message = "Datadog API key must be exactly 32 characters"
  }
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

variable "deployer_image_name" {
  description = "Name of the deployer container image"
  type        = string
  default     = "deployer"
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

  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], var.log_level)
    error_message = "log_level must be one of: DEBUG, INFO, WARNING, ERROR, CRITICAL"
  }
}

# Storage Configuration
variable "storage_connection_string" {
  description = "Optional storage account connection string. If not provided, a new storage account will be created"
  type        = string
  default     = null
  sensitive   = true
}

variable "storage_account_replication_type" {
  description = "Storage account replication type (only used if storage account is created)"
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.storage_account_replication_type)
    error_message = "storage_account_replication_type must be one of: LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS"
  }
}

# Subscription Configuration
variable "monitored_subscriptions" {
  description = "List of Azure subscription IDs to monitor and deploy forwarders to"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for sub in var.monitored_subscriptions : can(regex("^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$", sub))
    ])
    error_message = "Each subscription ID must be a valid GUID format"
  }
}
