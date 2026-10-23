# spoke

Spoke vending module: one call produces a complete, policy-compliant workload network.

- Resource group, VNet and subnets (default outbound access disabled, private endpoint network policies enabled).
- One NSG per subnet with a baseline `deny-internet-inbound` rule plus caller-supplied rules.
- Route table sending `0.0.0.0/0` to the hub firewall, BGP propagation disabled.
- Bidirectional hub peering (both sides owned by the spoke, so the hub code never changes).
- Links to every central Private DNS zone.
- Optional reference workload: a Storage Account with public network access disabled, reachable only through a private endpoint whose DNS record lands in the central hub zone.

Guardrails: subnets may not overlap each other or fall outside the spoke address space (plan-time failure).

Tests: `tests/spoke.tftest.hcl` (mocked azurerm provider).

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
| [azurerm_monitor_diagnostic_setting.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) | resource |
| [azurerm_network_security_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_network_security_rule.custom](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule) | resource |
| [azurerm_network_security_rule.deny_internet_inbound](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule) | resource |
| [azurerm_network_watcher_flow_log.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_watcher_flow_log) | resource |
| [azurerm_private_dns_zone_virtual_network_link.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link) | resource |
| [azurerm_private_endpoint.example_blob](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_route.default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route) | resource |
| [azurerm_route_table.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_table) | resource |
| [azurerm_storage_account.example](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_subnet.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet_network_security_group_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_subnet_route_table_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_route_table_association) | resource |
| [azurerm_virtual_network.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [azurerm_virtual_network_peering.hub_to_spoke](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) | resource |
| [azurerm_virtual_network_peering.spoke_to_hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| address\_space | Spoke VNet CIDR, e.g. `10.10.0.0/22`. | `string` | n/a | yes |
| hub | Hub connection details, taken from the hub module outputs. | ```object({ virtual_network_id = string virtual_network_name = string resource_group_name = string firewall_private_ip = string })``` | n/a | yes |
| location | Azure region for the spoke. | `string` | n/a | yes |
| log\_analytics\_workspace\_id | Log Analytics workspace that receives diagnostic logs and metrics. | `string` | n/a | yes |
| names | Name map produced by the `naming` module for this spoke. | `map(string)` | n/a | yes |
| subnets | Workload subnets keyed by short purpose name (`app`, `data`, `pe`). Every subnet gets its own NSG and the spoke route table. Set `private_endpoints = true` on the subnet that hosts private endpoints. | ```map(object({ address_prefix = string private_endpoints = optional(bool, false) service_endpoints = optional(list(string), []) delegation = optional(object({ name = string service = string actions = optional(list(string), []) })) nsg_rules = optional(map(object({ priority = number direction = string access = string protocol = string source_address_prefixes = list(string) destination_address_prefixes = list(string) destination_port_ranges = list(string) })), {}) }))``` | n/a | yes |
| deploy\_example\_private\_endpoint | Deploy a reference Storage Account (public access disabled) reachable only through a private endpoint. | `bool` | `false` | no |
| dns\_servers | Custom DNS servers for the spoke VNet. Empty list = Azure-provided DNS. | `list(string)` | `[]` | no |
| flow\_log\_settings | `flow_log_settings` output of the management module. When null, no VNet flow log is created. | ```object({ network_watcher_name = string network_watcher_resource_group_name = string storage_account_id = string workspace_guid = string workspace_resource_id = string workspace_location = string retention_days = number })``` | `null` | no |
| private\_dns\_zone\_ids | Central Private DNS zones (name => ID) to link this spoke to. Zones must live in the hub resource group. | `map(string)` | `{}` | no |
| tags | Tags applied to every resource in this module. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| address\_space | Spoke VNet CIDR. |
| default\_route | The forced-tunnelling route installed on every subnet. |
| example\_storage\_account | Reference private-only Storage Account, or null when not deployed. |
| network\_security\_group\_ids | Map of subnet key to the ID of the NSG protecting it. |
| resource\_group\_name | Spoke resource group name. |
| subnet\_ids | Map of subnet key to subnet ID. |
| virtual\_network\_id | Spoke VNet resource ID. |
| virtual\_network\_name | Spoke VNet name. |
<!-- END_TF_DOCS -->
