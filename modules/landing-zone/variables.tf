variable "environment" {
  description = "Environment short name (sbx, dev, test, uat, prod)."
  type        = string
}

variable "location" {
  description = "Primary Azure region."
  type        = string
}

variable "subscription_id" {
  description = "Target subscription GUID. Seeds globally unique names and scopes policies and budgets."
  type        = string
}

variable "tags" {
  description = "Organisation-wide tags. Must contain every tag listed in `governance.required_tags`."
  type        = map(string)
}

variable "hub" {
  description = "Hub (connectivity) settings. See the hub module for the meaning of each attribute."
  type = object({
    address_space         = string
    create_gateway_subnet = optional(bool, true)
    private_dns_zones     = optional(set(string))
    firewall = optional(object({
      sku_tier          = optional(string, "Basic")
      zones             = optional(list(string), [])
      threat_intel_mode = optional(string, "Deny")
      idps_mode         = optional(string, "Alert")
    }), {})
    bastion = optional(object({
      enabled = optional(bool, false)
      sku     = optional(string, "Basic")
    }), {})
  })
}

variable "spokes" {
  description = <<-EOT
    Spoke vending map: one entry = one fully wired workload network (resource group, VNet, subnets, NSGs,
    forced-tunnelling route table, hub peering, central DNS links, firewall egress rule, flow logs, diagnostics).
  EOT
  type = map(object({
    address_space                   = string
    egress_fqdns                    = optional(list(string), [])
    deploy_example_private_endpoint = optional(bool, false)
    tags                            = optional(map(string), {})
    subnets = map(object({
      address_prefix    = string
      private_endpoints = optional(bool, false)
      service_endpoints = optional(list(string), [])
      delegation = optional(object({
        name    = string
        service = string
        actions = optional(list(string), [])
      }))
      nsg_rules = optional(map(object({
        priority                     = number
        direction                    = string
        access                       = string
        protocol                     = string
        source_address_prefixes      = list(string)
        destination_address_prefixes = list(string)
        destination_port_ranges      = list(string)
      })), {})
    }))
  }))
  default = {}

  validation {
    condition     = alltrue([for key in keys(var.spokes) : can(regex("^[a-z][a-z0-9]{1,11}$", key))])
    error_message = "Spoke keys become part of resource names: use 2-12 lowercase alphanumeric characters starting with a letter."
  }

  validation {
    condition     = alltrue([for s in values(var.spokes) : can(cidrhost(s.address_space, 0))])
    error_message = "Every spoke address_space must be a valid IPv4 CIDR."
  }

  # Two CIDRs overlap exactly when they share a network address at the shorter of
  # their two prefix lengths. Peered VNets with overlapping ranges cannot route.
  validation {
    condition = length(flatten([
      for a_key, a in var.spokes : [
        for b_key, b in var.spokes : b_key
        if a_key != b_key && try(cidrhost("${split("/", a.address_space)[0]}/${min(tonumber(split("/", a.address_space)[1]), tonumber(split("/", b.address_space)[1]))}", 0) == cidrhost("${split("/", b.address_space)[0]}/${min(tonumber(split("/", a.address_space)[1]), tonumber(split("/", b.address_space)[1]))}", 0), false)
      ]
    ])) == 0
    error_message = "Spoke address spaces must not overlap each other."
  }
}

variable "management" {
  description = "Central logging settings."
  type = object({
    log_retention_days    = optional(number, 30)
    log_daily_quota_gb    = optional(number, -1)
    enable_vnet_flow_logs = optional(bool, true)
    network_watcher = optional(object({
      create              = optional(bool, false)
      name                = optional(string)
      resource_group_name = optional(string, "NetworkWatcherRG")
    }), {})
  })
  default = {}
}

variable "governance" {
  description = "Policy-as-code and cost guardrails applied at subscription scope."
  type = object({
    enabled                      = optional(bool, true)
    allowed_locations            = optional(list(string))
    required_tags                = optional(list(string), ["environment", "owner", "cost_center"])
    enforce                      = optional(bool, true)
    subnet_nsg_effect            = optional(string, "Audit")
    storage_public_access_effect = optional(string, "Deny")
    budget = object({
      amount         = number
      contact_emails = optional(list(string), [])
      contact_roles  = optional(list(string), ["Owner"])
    })
  })
}
