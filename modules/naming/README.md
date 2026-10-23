# naming

Pure-function module (no providers, no resources) that turns `workload`, `environment`, `location` and `instance` into
Cloud Adoption Framework style names: `<abbr>-<workload>-<env>-<region>-<instance>`, for example `vnet-payments-prod-weu-001`.

Globally unique names (Storage Accounts, Key Vaults) get a six-character hash of `unique_seed` (the subscription ID), so
they are stable across plans yet unique per subscription.

Tests: `tests/naming.tftest.hcl` (no provider needed).

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.8.0 |

### Modules

No modules.

### Resources

No resources.

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| environment | Environment short name. One of: sbx, dev, test, uat, prod. | `string` | n/a | yes |
| location | Azure region name, e.g. `westeurope`. Mapped to a short code for resource names. | `string` | n/a | yes |
| workload | Short workload or platform component name, e.g. `hub`, `mgmt`, `payments`. Lowercase letters and digits, 2-12 characters. | `string` | n/a | yes |
| instance | Three-digit instance number, used to run more than one copy of the same workload in a region. | `string` | `"001"` | no |
| unique\_seed | Optional seed (e.g. the subscription ID) hashed into a short suffix for globally unique names such as storage accounts. Defaults to the name suffix. | `string` | `null` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| abbreviations | CAF abbreviation map, for callers that compose child resource names (e.g. one NSG per subnet). |
| names | Ready-to-use resource names keyed by resource type, e.g. `names.virtual_network`. |
| region\_code | Short region code used in names, e.g. `weu`. |
| suffix | Name suffix shared by every resource in this scope, e.g. `hub-prod-weu-001`. |
<!-- END_TF_DOCS -->
