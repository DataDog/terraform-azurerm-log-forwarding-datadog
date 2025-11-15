# Datadog Azure Log Forwarding Automation

This Terraform module deploys the control plane infrastructure for Datadog Azure Log Forwarding automation. It creates:

- **Resource Group**: Container for all control plane resources
- **Container App Environment**: Hosting environment for containerized workloads
- **Deployer Container App Job**: Scheduled job that deploys and manages log forwarders across monitored subscriptions
- **Storage Account**: (Optional) Storage for the deployer job state and cache
- **IAM Roles**: Permissions for the deployer to manage resources across subscriptions

## Features

- **Automated Deployment**: Deployer runs every 30 minutes to ensure forwarders are deployed and configured
- **Multi-Subscription Support**: Monitor and forward logs from multiple Azure subscriptions
- **Flexible Storage**: Bring your own storage account or let the module create one
- **Managed Identity**: Uses system-assigned managed identity for secure, keyless authentication
- **Datadog Integration**: Built-in support for Datadog API integration

## Usage

### Basic Example

```hcl
module "log_automation" {
  source = "DataDog/log-automation-datadog/azurerm//modules/automation"

  resource_group_name = "dd-log-automation-rg"
  location            = "East US"
  control_plane_id    = "prod001"
  datadog_api_key     = var.datadog_api_key

  monitored_subscriptions = [
    "12345678-1234-1234-1234-123456789abc",
    "87654321-4321-4321-4321-cba987654321"
  ]

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}
```

### Advanced Example with Custom Storage

```hcl
module "log_automation" {
  source = "DataDog/log-automation-datadog/azurerm//modules/automation"

  resource_group_name = "dd-log-automation-rg"
  location            = "East US"
  control_plane_id    = "prod001"
  datadog_api_key     = var.datadog_api_key
  datadog_site        = "datadoghq.eu"

  # Use existing storage account
  storage_connection_string = var.existing_storage_connection_string

  # Custom container image
  image_registry      = "myregistry.azurecr.io"
  deployer_image_tag  = "v1.2.3"

  # Enhanced logging
  log_level           = "DEBUG"
  datadog_telemetry   = true

  monitored_subscriptions = [
    "12345678-1234-1234-1234-123456789abc"
  ]

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}
```

## Prerequisites

### Permissions Required

The principal running this Terraform module must have:

1. **In Control Plane Subscription**:
   - Contributor access to create resources in the resource group
   - User Access Administrator to assign roles to the deployer's managed identity

2. **In Each Monitored Subscription**:
   - User Access Administrator to grant permissions to the deployer's managed identity

### Monitored Subscription Setup

For each subscription in `monitored_subscriptions`, ensure:
- The resource group with the same name as `resource_group_name` exists (or the deployer can create it)
- The deployer will need Contributor and Monitoring Contributor permissions (automatically assigned by this module)

## How It Works

1. **Deployer Job**: Runs every 30 minutes via cron schedule (`*/30 * * * *`)
2. **Resource Discovery**: Scans monitored subscriptions for resources requiring log forwarding
3. **Forwarder Deployment**: Deploys Azure Functions to forward logs to Datadog
4. **Configuration**: Configures diagnostic settings on Azure resources
5. **State Management**: Maintains state in storage account for idempotent operations

## Notes

- **Control Plane ID**: Must be unique, alphanumeric, lowercase, max 12 characters. Used in all resource names.
- **Storage Account URL**: The deployer uses a Datadog-managed storage account (`https://ddazurelfo.blob.core.windows.net`) for artifacts. This is separate from the state storage account.
- **Datadog API Key**: Must be exactly 32 characters. Keep this secure and consider using Azure Key Vault.
- **Container Registry**: Default is `datadoghq.azurecr.io`. Ensure you have access or provide your own registry.

## Outputs

The module exports various outputs including:
- Container app environment and deployer task IDs
- Deployer managed identity principal ID (for additional role assignments)
- Storage account details (if created by module)
- Control plane metadata

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.4 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | ~> 4.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_container_app_environment.environment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app_environment) | resource |
| [azurerm_container_app_job.deployer](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app_job) | resource |
| [azurerm_resource_group.resource_group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.deployer_contributor](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.deployer_monitoring_contributor](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.deployer_website_contributor](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_storage_account.storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_control_plane_id"></a> [control\_plane\_id](#input\_control\_plane\_id) | Unique identifier for the control plane (alphanumeric, lowercase, max 12 chars) | `string` | n/a | yes |
| <a name="input_datadog_api_key"></a> [datadog\_api\_key](#input\_datadog\_api\_key) | Datadog API key for sending logs and metrics | `string` | n/a | yes |
| <a name="input_datadog_site"></a> [datadog\_site](#input\_datadog\_site) | Datadog site (e.g., datadoghq.com, datadoghq.eu, us3.datadoghq.com) | `string` | `"datadoghq.com"` | no |
| <a name="input_datadog_telemetry"></a> [datadog\_telemetry](#input\_datadog\_telemetry) | Enable Datadog telemetry | `bool` | `false` | no |
| <a name="input_deployer_image_name"></a> [deployer\_image\_name](#input\_deployer\_image\_name) | Name of the deployer container image | `string` | `"deployer"` | no |
| <a name="input_deployer_image_tag"></a> [deployer\_image\_tag](#input\_deployer\_image\_tag) | Tag of the deployer container image | `string` | `"latest"` | no |
| <a name="input_image_registry"></a> [image\_registry](#input\_image\_registry) | Container registry for deployer image | `string` | `"datadoghq.azurecr.io"` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region where resources will be created | `string` | `"East US"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for the deployer (DEBUG, INFO, WARNING, ERROR, CRITICAL) | `string` | `"INFO"` | no |
| <a name="input_monitored_subscriptions"></a> [monitored\_subscriptions](#input\_monitored\_subscriptions) | List of Azure subscription IDs to monitor and deploy forwarders to | `list(string)` | `[]` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group where resources will be created | `string` | n/a | yes |
| <a name="input_storage_account_replication_type"></a> [storage\_account\_replication\_type](#input\_storage\_account\_replication\_type) | Storage account replication type (only used if storage account is created) | `string` | `"LRS"` | no |
| <a name="input_storage_connection_string"></a> [storage\_connection\_string](#input\_storage\_connection\_string) | Optional storage account connection string. If not provided, a new storage account will be created | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_container_app_environment_id"></a> [container\_app\_environment\_id](#output\_container\_app\_environment\_id) | ID of the container app environment |
| <a name="output_container_app_environment_name"></a> [container\_app\_environment\_name](#output\_container\_app\_environment\_name) | Name of the container app environment |
| <a name="output_control_plane_id"></a> [control\_plane\_id](#output\_control\_plane\_id) | Control plane identifier |
| <a name="output_deployer_task_id"></a> [deployer\_task\_id](#output\_deployer\_task\_id) | ID of the deployer container app job |
| <a name="output_deployer_task_name"></a> [deployer\_task\_name](#output\_deployer\_task\_name) | Name of the deployer container app job |
| <a name="output_deployer_task_principal_id"></a> [deployer\_task\_principal\_id](#output\_deployer\_task\_principal\_id) | Principal ID of the deployer task's managed identity |
| <a name="output_deployer_task_tenant_id"></a> [deployer\_task\_tenant\_id](#output\_deployer\_task\_tenant\_id) | Tenant ID of the deployer task's managed identity |
| <a name="output_resource_group_id"></a> [resource\_group\_id](#output\_resource\_group\_id) | ID of the created resource group |
| <a name="output_resource_group_location"></a> [resource\_group\_location](#output\_resource\_group\_location) | Location of the created resource group |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | Name of the created resource group |
| <a name="output_storage_account_id"></a> [storage\_account\_id](#output\_storage\_account\_id) | ID of the storage account (if created by module) |
| <a name="output_storage_account_name"></a> [storage\_account\_name](#output\_storage\_account\_name) | Name of the storage account (if created by module) |
| <a name="output_storage_connection_string"></a> [storage\_connection\_string](#output\_storage\_connection\_string) | Connection string for the storage account |
<!-- END_TF_DOCS -->