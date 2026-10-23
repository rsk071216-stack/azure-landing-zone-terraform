# landing-zone

Composition module wiring `naming`, `management`, `hub`, `spoke` (for_each over `var.spokes`) and `governance` into
one landing zone. Environment roots in `environments/` call only this module.

Cross-input guardrails (spoke vs hub overlap, required tags present) run as preconditions on `terraform_data.guardrails`
and fail the plan before anything is created.

Tests: `tests/landing_zone.tftest.hcl` (mocked azurerm provider): the architectural contract of the whole repository.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.8.0 |
| azurerm | >= 4.80.0, < 5.0.0 |

### Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| governance | ../governance | n/a |
| hub | ../hub | n/a |
| management | ../management | n/a |
| naming\_hub | ../naming | n/a |
| naming\_management | ../naming | n/a |
| naming\_spoke | ../naming | n/a |
| spoke | ../spoke | n/a |

### Resources

| Name | Type |
| ---- | ---- |
| [terraform_data.guardrails](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| environment | Environment short name (sbx, dev, test, uat, prod). | `string` | n/a | yes |
| governance | Policy-as-code and cost guardrails applied at subscription scope. | ```object({ enabled = optional(bool, true) allowed_locations = optional(list(string)) required_tags = optional(list(string), ["environment", "owner", "cost_center"]) enforce = optional(bool, true) subnet_nsg_effect = optional(string, "Audit") storage_public_access_effect = optional(string, "Deny") budget = object({ amount = number contact_emails = optional(list(string), []) contact_roles = optional(list(string), ["Owner"]) }) })``` | n/a | yes |
| hub | Hub (connectivity) settings. See the hub module for the meaning of each attribute. | ```object({ address_space = string create_gateway_subnet = optional(bool, true) private_dns_zones = optional(set(string)) firewall = optional(object({ sku_tier = optional(string, "Basic") zones = optional(list(string), []) threat_intel_mode = optional(string, "Deny") idps_mode = optional(string, "Alert") }), {}) bastion = optional(object({ enabled = optional(bool, false) sku = optional(string, "Basic") }), {}) })``` | n/a | yes |
| location | Primary Azure region. | `string` | n/a | yes |
| subscription\_id | Target subscription GUID. Seeds globally unique names and scopes policies and budgets. | `string` | n/a | yes |
| tags | Organisation-wide tags. Must contain every tag listed in `governance.required_tags`. | `map(string)` | n/a | yes |
| management | Central logging settings. | ```object({ log_retention_days = optional(number, 30) log_daily_quota_gb = optional(number, -1) enable_vnet_flow_logs = optional(bool, true) network_watcher = optional(object({ create = optional(bool, false) name = optional(string) resource_group_name = optional(string, "NetworkWatcherRG") }), {}) })``` | `{}` | no |
| spokes | Spoke vending map: one entry = one fully wired workload network (resource group, VNet, subnets, NSGs, forced-tunnelling route table, hub peering, central DNS links, firewall egress rule, flow logs, diagnostics). | ```map(object({ address_space = string egress_fqdns = optional(list(string), []) deploy_example_private_endpoint = optional(bool, false) tags = optional(map(string), {}) subnets = map(object({ address_prefix = string private_endpoints = optional(bool, false) service_endpoints = optional(list(string), []) delegation = optional(object({ name = string service = string actions = optional(list(string), []) })) nsg_rules = optional(map(object({ priority = number direction = string access = string protocol = string source_address_prefixes = list(string) destination_address_prefixes = list(string) destination_port_ranges = list(string) })), {}) })) }))``` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| example\_private\_endpoints | Reference private-only Storage Accounts, keyed by spoke (only spokes that deploy one). |
| hub | Hub connectivity details. |
| log\_analytics\_workspace\_id | Central Log Analytics workspace resource ID. |
| policy\_assignment\_ids | Policy assignment IDs, or an empty map when governance is disabled. |
| private\_dns\_zone\_ids | Central Private DNS zone IDs, keyed by zone name. |
| required\_tags | Tags applied to every resource group (after defaults are merged). |
| resource\_names | Generated names per scope, useful for documentation and runbooks. |
| spokes | Per-spoke network details, keyed by spoke name. |
<!-- END_TF_DOCS -->
