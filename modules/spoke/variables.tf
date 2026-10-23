
variable "names" {
  description = "Name map produced by the `naming` module for this spoke."
  type        = map(string)
}

variable "location" {
  description = "Azure region for the spoke."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource in this module."
  type        = map(string)
  default     = {}
}

variable "address_space" {
  description = "Spoke VNet CIDR, e.g. `10.10.0.0/22`."
  type        = string

  validation {
    condition     = can(cidrhost(var.address_space, 0))
    error_message = "address_space must be a valid IPv4 CIDR."
  }
}

variable "subnets" {
  description = <<-EOT
    Workload subnets keyed by short purpose name (`app`, `data`, `pe`). Every subnet gets its own NSG and the
    spoke route table. Set `private_endpoints = true` on the subnet that hosts private endpoints.
  EOT
  type = map(object({
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

  validation {
    condition     = alltrue([for s in values(var.subnets) : can(cidrhost(s.address_prefix, 0))])
    error_message = "Every subnet address_prefix must be a valid IPv4 CIDR."
  }

  # Two CIDRs overlap exactly when they share a network address at the shorter of their two prefix lengths.
  validation {
    condition = length(flatten([
      for a_key, a in var.subnets : [
        for b_key, b in var.subnets : b_key
        if a_key != b_key && try(cidrhost("${split("/", a.address_prefix)[0]}/${min(tonumber(split("/", a.address_prefix)[1]), tonumber(split("/", b.address_prefix)[1]))}", 0) == cidrhost("${split("/", b.address_prefix)[0]}/${min(tonumber(split("/", a.address_prefix)[1]), tonumber(split("/", b.address_prefix)[1]))}", 0), false)
      ]
    ])) == 0
    error_message = "Subnet address prefixes within a spoke must not overlap."
  }
}

variable "hub" {
  description = "Hub connection details, taken from the hub module outputs."
  type = object({
    virtual_network_id   = string
    virtual_network_name = string
    resource_group_name  = string
    firewall_private_ip  = string
  })
}

variable "dns_servers" {
  description = "Custom DNS servers for the spoke VNet. Empty list = Azure-provided DNS."
  type        = list(string)
  default     = []
}

variable "private_dns_zone_ids" {
  description = "Central Private DNS zones (name => ID) to link this spoke to. Zones must live in the hub resource group."
  type        = map(string)
  default     = {}
}

variable "deploy_example_private_endpoint" {
  description = "Deploy a reference Storage Account (public access disabled) reachable only through a private endpoint."
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace that receives diagnostic logs and metrics."
  type        = string
}

variable "flow_log_settings" {
  description = "`flow_log_settings` output of the management module. When null, no VNet flow log is created."
  type = object({
    network_watcher_name                = string
    network_watcher_resource_group_name = string
    storage_account_id                  = string
    workspace_guid                      = string
    workspace_resource_id               = string
    workspace_location                  = string
    retention_days                      = number
  })
  default = null
}
