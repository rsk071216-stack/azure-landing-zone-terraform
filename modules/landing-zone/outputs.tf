output "hub" {
  description = "Hub connectivity details."
  value = {
    resource_group_name  = module.hub.resource_group_name
    virtual_network_id   = module.hub.virtual_network_id
    virtual_network_name = module.hub.virtual_network_name
    subnet_prefixes      = module.hub.subnet_prefixes
    firewall_private_ip  = module.hub.firewall_private_ip
    spoke_dns_servers    = module.hub.spoke_dns_servers
  }
}

output "spokes" {
  description = "Per-spoke network details, keyed by spoke name."
  value = {
    for key, s in module.spoke : key => {
      resource_group_name  = s.resource_group_name
      virtual_network_id   = s.virtual_network_id
      virtual_network_name = s.virtual_network_name
      address_space        = s.address_space
      subnet_ids           = s.subnet_ids
      default_route        = s.default_route
    }
  }
}

output "example_private_endpoints" {
  description = "Reference private-only Storage Accounts, keyed by spoke (only spokes that deploy one)."
  value       = { for key, s in module.spoke : key => s.example_storage_account if s.example_storage_account != null }
}

output "private_dns_zone_ids" {
  description = "Central Private DNS zone IDs, keyed by zone name."
  value       = module.hub.private_dns_zone_ids
}

output "log_analytics_workspace_id" {
  description = "Central Log Analytics workspace resource ID."
  value       = module.management.log_analytics_workspace_id
}

output "resource_names" {
  description = "Generated names per scope, useful for documentation and runbooks."
  value = merge(
    {
      management = module.naming_management.names
      hub        = module.naming_hub.names
    },
    { for key, n in module.naming_spoke : key => n.names },
  )
}

output "required_tags" {
  description = "Tags applied to every resource group (after defaults are merged)."
  value       = local.tags
}

output "policy_assignment_ids" {
  description = "Policy assignment IDs, or an empty map when governance is disabled."
  value       = var.governance.enabled ? module.governance[0].policy_assignment_ids : {}
}
