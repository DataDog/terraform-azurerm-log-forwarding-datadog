# Upgrading Guide

## v1.x → v2.0

### Overview

The `automation` module's control plane has been migrated from Azure Function Apps to Container App Jobs. This is a breaking change: upgrading from v1.x will destroy the existing function apps and create new container app jobs in their place.

The `forwarder` and `automated-resource-group` modules are unchanged.

### Minimum Terraform version

v2.0 requires Terraform **>= 1.7**. Upgrade your Terraform installation before applying.

### What changes on `terraform apply`

The following resources will be **destroyed**:

| Resource | Type |
|----------|------|
| `resources-task-<id>` | `azurerm_linux_function_app` |
| `scaling-task-<id>` | `azurerm_linux_function_app` |
| `diagnostic-settings-task-<id>` | `azurerm_linux_function_app` |
| `control-plane-asp-<id>` | `azurerm_service_plan` |
| `resources-task-<id>` (file share) | `azurerm_storage_share` |

The following resources will be **created**:

| Resource | Type |
|----------|------|
| `resources-task-<id>` | `azurerm_container_app_job` |
| `scaling-task-<id>` | `azurerm_container_app_job` |
| `diagnostic-settings-task-<id>` | `azurerm_container_app_job` |

All other resources (storage account, cache container, deployer task, container app environment, role assignments) are preserved or updated in place.

### Breaking: managed identity principal IDs change

The outputs `resources_task_principal_id`, `scaling_task_principal_id`, and `diagnostic_settings_task_principal_id` previously referred to the function app managed identities. They now refer to the new container app job managed identities.

If you reference these outputs in your own Terraform configuration (e.g. for additional role assignments), those dependent resources will also be replaced on upgrade.

### Upgrade steps

1. Upgrade your Terraform installation to >= 1.7.
2. Update your module version constraint to `~> 2.0`.
3. Run `terraform init -upgrade`.
4. Run `terraform plan` and review the proposed changes. Expect to see the five destroys and three creates listed above, plus replacements of any role assignments that reference the task principal ID outputs.
5. Run `terraform apply`.

During the apply, there will be a brief window where the old function apps have been destroyed and the new container app jobs are not yet running. Log forwarding will resume automatically once the new jobs execute on their schedule (`*/5 * * * *`).
