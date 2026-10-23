variable "subscription_id" {
  description = "Subscription GUID that policies and the budget are scoped to."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "subscription_id must be a GUID, not a resource ID."
  }
}

variable "name_prefix" {
  description = "Prefix for policy definition and assignment names, e.g. `alz-dev`."
  type        = string
}

variable "location" {
  description = "Region for the managed identity of `Modify` policy assignments."
  type        = string
}

variable "allowed_locations" {
  description = "Regions where resources and resource groups may be created."
  type        = list(string)

  validation {
    condition     = length(var.allowed_locations) > 0
    error_message = "allowed_locations must contain at least one region."
  }
}

variable "required_tags" {
  description = "Tags every resource group must carry (Deny). Resources inherit missing tags from their resource group (Modify)."
  type        = list(string)
  default     = ["environment", "owner", "cost_center"]
}

variable "enforce" {
  description = "When false, every assignment runs in DoNotEnforce mode: compliance is reported, nothing is blocked. Useful for a brownfield rollout."
  type        = bool
  default     = true
}

variable "subnet_nsg_effect" {
  description = "Effect for the custom 'subnets must have an NSG' policy. Audit by default; see ADR-0005 before switching to Deny."
  type        = string
  default     = "Audit"

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.subnet_nsg_effect)
    error_message = "subnet_nsg_effect must be Audit, Deny or Disabled."
  }
}

variable "storage_public_access_effect" {
  description = "Effect for the built-in 'Storage accounts should disable public network access' policy."
  type        = string
  default     = "Deny"

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.storage_public_access_effect)
    error_message = "storage_public_access_effect must be Audit, Deny or Disabled."
  }
}

variable "central_dns_resource_group_id" {
  description = "Resource group that hosts the central Private DNS zones; excluded from the 'no privatelink zones' policy."
  type        = string
}

variable "storage_public_access_exemptions" {
  description = "Resource groups (key => resource group ID) exempted from the storage public-access policy, e.g. the flow-log storage account that Network Watcher writes to as a trusted service."
  type        = map(string)
  default     = {}
}

variable "diagnostic_resource_types" {
  description = "Resource types audited for a diagnostic setting."
  type        = list(string)
  default = [
    "Microsoft.Network/azureFirewalls",
    "Microsoft.Network/bastionHosts",
    "Microsoft.Network/networkSecurityGroups",
    "Microsoft.Network/publicIPAddresses",
    "Microsoft.Network/virtualNetworks",
    "Microsoft.KeyVault/vaults",
  ]
}

variable "budget" {
  description = "Monthly subscription budget. Alerts at 80% and 100% of actual spend and 100% of forecast."
  type = object({
    amount         = number
    contact_emails = optional(list(string), [])
    contact_roles  = optional(list(string), ["Owner"])
  })

  validation {
    condition     = var.budget.amount > 0
    error_message = "budget.amount must be greater than zero."
  }
}
