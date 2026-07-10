# Unless explicitly stated otherwise all files in this repository are licensed under the Apache-2 License.

# This product includes software developed at Datadog (https://www.datadoghq.com/) Copyright 2025 Datadog, Inc.

output "control_plane_id" {
  description = "The control plane identifier used for resource naming"
  value       = local.control_plane_id
}

output "resource_group_name" {
  description = "Name of the automation resource group"
  value       = azurerm_resource_group.resource_group.name
}

output "resources_task_principal_id" {
  description = "Managed identity principal ID of the resources task container app job (for additional role assignments)"
  value       = azurerm_container_app_job.resources_task.identity[0].principal_id
}

output "scaling_task_principal_id" {
  description = "Managed identity principal ID of the scaling task container app job (for additional role assignments)"
  value       = azurerm_container_app_job.scaling_task.identity[0].principal_id
}

output "diagnostic_settings_task_principal_id" {
  description = "Managed identity principal ID of the diagnostic settings task container app job (for additional role assignments)"
  value       = azurerm_container_app_job.diagnostic_settings_task.identity[0].principal_id
}

# Deployer Outputs

output "deployer_task_name" {
  description = "Name of the deployer container app job"
  value       = azurerm_container_app_job.deployer_task.name
}

output "deployer_task_id" {
  description = "Resource ID of the deployer container app job"
  value       = azurerm_container_app_job.deployer_task.id
}

output "deployer_task_principal_id" {
  description = "Managed identity principal ID of the deployer task (for additional role assignments)"
  value       = azurerm_container_app_job.deployer_task.identity[0].principal_id
}

output "container_app_environment_id" {
  description = "Resource ID of the deployer container app environment"
  value       = azurerm_container_app_environment.deployer_env.id
}

output "container_app_environment_name" {
  description = "Name of the deployer container app environment"
  value       = azurerm_container_app_environment.deployer_env.name
}
