# hub

Connectivity hub for a hub-and-spoke topology:

- Hub VNet with a deterministic platform subnet plan (`AzureFirewallSubnet`, `AzureFirewallManagementSubnet`, `AzureBastionSubnet`, `GatewaySubnet`).
- Azure Firewall (Basic, Standard or Premium) with a Firewall Policy and two rule collection groups: platform egress and per-spoke workload egress.
- Optional Azure Bastion.
- Centralised Private Link DNS zones, linked to the hub (spokes link themselves).
- Diagnostic settings to Log Analytics (resource-specific tables for the firewall) and VNet flow logs with traffic analytics.

The firewall private IP is computed as the `.4` host of `AzureFirewallSubnet`, which lets spokes create their route tables
in parallel with the firewall deployment (see `docs/adr/0003-deterministic-firewall-ip.md`).

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
| [azurerm_bastion_host.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/bastion_host) | resource |
| [azurerm_firewall.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall) | resource |
| [azurerm_firewall_policy.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall_policy) | resource |
| [azurerm_firewall_policy_rule_collection_group.platform](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall_policy_rule_collection_group) | resource |
| [azurerm_firewall_policy_rule_collection_group.workloads](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall_policy_rule_collection_group) | resource |
| [azurerm_monitor_diagnostic_setting.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) | resource |
| [azurerm_network_watcher_flow_log.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_watcher_flow_log) | resource |
| [azurerm_private_dns_zone.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) | resource |
| [azurerm_private_dns_zone_virtual_network_link.hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link) | resource |
| [azurerm_public_ip.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_subnet.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_virtual_network.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| address\_space | Hub VNet CIDR. Must be between /16 and /24; platform subnets are carved out automatically. | `string` | n/a | yes |
| location | Azure region for the hub. | `string` | n/a | yes |
| log\_analytics\_workspace\_id | Log Analytics workspace that receives diagnostic logs and metrics. | `string` | n/a | yes |
| names | Name map produced by the `naming` module for the hub scope. | `map(string)` | n/a | yes |
| bastion | Azure Bastion settings. Disabled by default to save cost; enable for break-glass access to private VMs. | ```object({ enabled = optional(bool, false) sku = optional(string, "Basic") })``` | `{}` | no |
| create\_gateway\_subnet | Reserve `GatewaySubnet` for a future VPN or ExpressRoute gateway. The gateway itself is not deployed. | `bool` | `true` | no |
| firewall | Azure Firewall settings. `sku_tier = "Basic"` keeps a lab affordable; Standard adds DNS proxy and threat-intelligence deny mode; Premium adds IDPS and TLS inspection. | ```object({ sku_tier = optional(string, "Basic") zones = optional(list(string), []) threat_intel_mode = optional(string, "Deny") idps_mode = optional(string, "Alert") })``` | `{}` | no |
| flow\_log\_settings | `flow_log_settings` output of the management module. When null, no VNet flow log is created. | ```object({ network_watcher_name = string network_watcher_resource_group_name = string storage_account_id = string workspace_guid = string workspace_resource_id = string workspace_location = string retention_days = number })``` | `null` | no |
| platform\_source\_addresses | Source ranges allowed to use the platform egress rules (NTP, OS updates, Azure management and monitoring endpoints). | `list(string)` | ```[ "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16" ]``` | no |
| private\_dns\_zones | Private Link DNS zones hosted centrally in the hub and linked to every VNet. | `set(string)` | ```[ "privatelink.azurecr.io", "privatelink.blob.core.windows.net", "privatelink.database.windows.net", "privatelink.dfs.core.windows.net", "privatelink.file.core.windows.net", "privatelink.monitor.azure.com", "privatelink.queue.core.windows.net", "privatelink.servicebus.windows.net", "privatelink.table.core.windows.net", "privatelink.vaultcore.azure.net" ]``` | no |
| spoke\_egress\_rules | Per-spoke FQDN allow-lists, generated by the landing-zone module from the spoke map. Key = spoke name. | ```map(object({ source_addresses = list(string) destination_fqdns = list(string) }))``` | `{}` | no |
| tags | Tags applied to every resource in this module. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| firewall\_id | Azure Firewall resource ID. |
| firewall\_policy\_id | Firewall policy ID, for attaching extra rule collection groups from outside this module. |
| firewall\_private\_ip | Private IP of Azure Firewall: the next hop for every spoke default route. |
| private\_dns\_zone\_ids | Map of Private DNS zone name to resource ID. |
| resource\_group\_id | Hub resource group ID, used as a policy exclusion scope for central DNS zones. |
| resource\_group\_name | Hub resource group name (also hosts the central Private DNS zones). |
| spoke\_dns\_servers | DNS servers spokes should use: the firewall DNS proxy on Standard/Premium, Azure-provided DNS (empty list) on Basic. |
| subnet\_prefixes | Platform subnets actually deployed, keyed by their Azure-mandated names. |
| virtual\_network\_id | Hub VNet resource ID. |
| virtual\_network\_name | Hub VNet name. |
<!-- END_TF_DOCS -->
