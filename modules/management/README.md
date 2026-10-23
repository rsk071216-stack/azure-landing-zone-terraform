# management

Central operations resources for the landing zone:

- Log Analytics workspace (Entra ID-only access, optional daily ingestion cap for non-production).
- Storage account for VNet flow logs (network rules default to `Deny`, trusted Azure services only).
- Optional Network Watcher for subscriptions that disable Azure's automatic creation.

Its `flow_log_settings` output is passed unchanged to the hub and every spoke.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.8.0 |
| azurerm | >= 4.80.0, < 5.0.0 |

### Modules

No modules.

### Resources

| Name | Type |
| ---- | ---- |
| [azurerm_log_analytics_workspace.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace) | resource |
| [azurerm_network_watcher.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_watcher) | resource |
| [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_storage_account.flow_logs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| location | Azure region for management resources. | `string` | n/a | yes |
| names | Name map produced by the `naming` module for the management scope. | `map(string)` | n/a | yes |
| enable\_vnet\_flow\_logs | Create the storage account used by VNet flow logs (NSG flow logs are retired by Microsoft). | `bool` | `true` | no |
| log\_daily\_quota\_gb | Daily ingestion cap in GB. Protects non-production budgets from runaway logging; use -1 for no cap. | `number` | `-1` | no |
| log\_retention\_days | Interactive retention for the Log Analytics workspace (30-730 days). | `number` | `30` | no |
| network\_watcher | Network Watcher used for VNet flow logs. Azure auto-creates `NetworkWatcher_<region>` in `NetworkWatcherRG` unless the subscription opted out; set `create = true` to manage it here instead. | ```object({ create = optional(bool, false) name = optional(string) resource_group_name = optional(string, "NetworkWatcherRG") })``` | `{}` | no |
| tags | Tags applied to every resource in this module. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| flow\_log\_settings | Settings consumed by hub and spoke modules to create VNet flow logs; null when flow logs are disabled. |
| log\_analytics\_workspace\_guid | Workspace (customer) ID, required by traffic analytics. |
| log\_analytics\_workspace\_id | Azure resource ID of the central Log Analytics workspace (diagnostic settings target). |
| resource\_group\_id | Management resource group ID. |
| resource\_group\_name | Management resource group name. |
<!-- END_TF_DOCS -->
