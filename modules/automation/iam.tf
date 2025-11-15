# Role Assignment: Website Contributor at Resource Group Level
# Allows the deployer to manage function app deployments in the control plane resource group
resource "azurerm_role_assignment" "deployer_website_contributor" {
  scope                = azurerm_resource_group.resource_group.id
  role_definition_name = "Website Contributor"
  principal_id         = azurerm_container_app_job.deployer.identity[0].principal_id
}

# Role Assignment: Monitoring Contributor at Subscription Level
# Allows the deployer to configure diagnostic settings and monitoring in each monitored subscription
resource "azurerm_role_assignment" "deployer_monitoring_contributor" {
  for_each = toset(var.monitored_subscriptions)

  scope                = "/subscriptions/${each.value}"
  role_definition_name = "Monitoring Contributor"
  principal_id         = azurerm_container_app_job.deployer.identity[0].principal_id
}

# Role Assignment: Contributor at Resource Group Level in Monitored Subscriptions
# Allows the deployer to deploy and manage forwarder resources in monitored subscriptions
resource "azurerm_role_assignment" "deployer_contributor" {
  for_each = toset(var.monitored_subscriptions)

  scope                = "/subscriptions/${each.value}/resourceGroups/${azurerm_resource_group.resource_group.name}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_container_app_job.deployer.identity[0].principal_id
}
