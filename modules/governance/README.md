# governance

Policy-as-code and cost guardrails at subscription scope.

| Assignment | Type | Effect | Risk addressed |
|---|---|---|---|
| Allowed locations (resources and resource groups) | Built-in | Deny | Data residency, sprawl |
| Require tag on resource groups (one per tag) | Built-in | Deny | Unallocated cost, missing ownership |
| Inherit tag from resource group (one per tag) | Built-in | Modify | Tag drift on child resources |
| Network interfaces should not have public IPs | Built-in | Deny | Direct internet exposure bypassing the firewall |
| Storage accounts should disable public network access | Built-in | Deny (configurable) | Data exfiltration through public endpoints |
| Audit diagnostic setting for selected resource types | Built-in | AuditIfNotExists | Blind spots in logging |
| Deny privatelink DNS zones outside the hub | Custom | Deny | Split-brain Private Link DNS |
| Subnets must have an NSG | Custom | Audit (configurable) | Unfiltered east-west traffic |

Plus a monthly subscription budget with 80% / 100% actual and 100% forecast alerts.

Tests: `tests/governance.tftest.hcl` (mocked azurerm provider).

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
| [azurerm_consumption_budget_subscription.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/consumption_budget_subscription) | resource |
| [azurerm_policy_definition.deny_privatelink_dns_zones](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/policy_definition) | resource |
| [azurerm_policy_definition.subnet_requires_nsg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/policy_definition) | resource |
| [azurerm_resource_group_policy_exemption.storage_public_access](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group_policy_exemption) | resource |
| [azurerm_role_assignment.inherit_tag_remediation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_subscription_policy_assignment.deny_privatelink_dns_zones](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subscription_policy_assignment) | resource |
| [azurerm_subscription_policy_assignment.inherit_tag_from_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subscription_policy_assignment) | resource |
| [azurerm_subscription_policy_assignment.require_tag_on_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subscription_policy_assignment) | resource |
| [azurerm_subscription_policy_assignment.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subscription_policy_assignment) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| allowed\_locations | Regions where resources and resource groups may be created. | `list(string)` | n/a | yes |
| budget | Monthly subscription budget. Alerts at 80% and 100% of actual spend and 100% of forecast. | ```object({ amount = number contact_emails = optional(list(string), []) contact_roles = optional(list(string), ["Owner"]) })``` | n/a | yes |
| central\_dns\_resource\_group\_id | Resource group that hosts the central Private DNS zones; excluded from the 'no privatelink zones' policy. | `string` | n/a | yes |
| location | Region for the managed identity of `Modify` policy assignments. | `string` | n/a | yes |
| name\_prefix | Prefix for policy definition and assignment names, e.g. `alz-dev`. | `string` | n/a | yes |
| subscription\_id | Subscription GUID that policies and the budget are scoped to. | `string` | n/a | yes |
| diagnostic\_resource\_types | Resource types audited for a diagnostic setting. | `list(string)` | ```[ "Microsoft.Network/azureFirewalls", "Microsoft.Network/bastionHosts", "Microsoft.Network/networkSecurityGroups", "Microsoft.Network/publicIPAddresses", "Microsoft.Network/virtualNetworks", "Microsoft.KeyVault/vaults" ]``` | no |
| enforce | When false, every assignment runs in DoNotEnforce mode: compliance is reported, nothing is blocked. Useful for a brownfield rollout. | `bool` | `true` | no |
| required\_tags | Tags every resource group must carry (Deny). Resources inherit missing tags from their resource group (Modify). | `list(string)` | ```[ "environment", "owner", "cost_center" ]``` | no |
| storage\_public\_access\_effect | Effect for the built-in 'Storage accounts should disable public network access' policy. | `string` | `"Deny"` | no |
| storage\_public\_access\_exemptions | Resource groups (key => resource group ID) exempted from the storage public-access policy, e.g. the flow-log storage account that Network Watcher writes to as a trusted service. | `map(string)` | `{}` | no |
| subnet\_nsg\_effect | Effect for the custom 'subnets must have an NSG' policy. Audit by default; see ADR-0005 before switching to Deny. | `string` | `"Audit"` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| budget\_id | Subscription budget ID. |
| custom\_policy\_definition\_ids | IDs of the custom policy definitions created by this module. |
| policy\_assignment\_ids | Map of assignment name to policy assignment ID. |
<!-- END_TF_DOCS -->
