# Resource Group Outputs
output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.resource_group.name
}

output "resource_group_id" {
  description = "ID of the created resource group"
  value       = azurerm_resource_group.resource_group.id
}

output "resource_group_location" {
  description = "Location of the created resource group"
  value       = azurerm_resource_group.resource_group.location
}

# Container App Environment Outputs
output "container_app_environment_name" {
  description = "Name of the container app environment"
  value       = azurerm_container_app_environment.environment.name
}

output "container_app_environment_id" {
  description = "ID of the container app environment"
  value       = azurerm_container_app_environment.environment.id
}

# Deployer Task Outputs
output "deployer_task_name" {
  description = "Name of the deployer container app job"
  value       = azurerm_container_app_job.deployer.name
}

output "deployer_task_id" {
  description = "ID of the deployer container app job"
  value       = azurerm_container_app_job.deployer.id
}

output "deployer_task_principal_id" {
  description = "Principal ID of the deployer task's managed identity"
  value       = azurerm_container_app_job.deployer.identity[0].principal_id
}

output "deployer_task_tenant_id" {
  description = "Tenant ID of the deployer task's managed identity"
  value       = azurerm_container_app_job.deployer.identity[0].tenant_id
}

# Storage Account Outputs
output "storage_account_name" {
  description = "Name of the storage account (if created by module)"
  value       = var.storage_connection_string == null ? azurerm_storage_account.storage[0].name : null
}

output "storage_account_id" {
  description = "ID of the storage account (if created by module)"
  value       = var.storage_connection_string == null ? azurerm_storage_account.storage[0].id : null
}

output "storage_connection_string" {
  description = "Connection string for the storage account"
  value       = local.storage_connection_string
  sensitive   = true
}

# Control Plane Outputs
output "control_plane_id" {
  description = "Control plane identifier"
  value       = var.control_plane_id
}
