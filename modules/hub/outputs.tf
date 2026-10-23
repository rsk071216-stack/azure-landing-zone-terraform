output "resource_group_name" {
  description = "Hub resource group name (also hosts the central Private DNS zones)."
  value       = azurerm_resource_group.this.name
}

output "resource_group_id" {
  description = "Hub resource group ID, used as a policy exclusion scope for central DNS zones."
  value       = azurerm_resource_group.this.id
}

output "virtual_network_id" {
  description = "Hub VNet resource ID."
  value       = azurerm_virtual_network.this.id
}

output "virtual_network_name" {
  description = "Hub VNet name."
  value       = azurerm_virtual_network.this.name
}

output "subnet_prefixes" {
  description = "Platform subnets actually deployed, keyed by their Azure-mandated names."
  value       = local.subnets
}

output "firewall_private_ip" {
  description = "Private IP of Azure Firewall: the next hop for every spoke default route."
  value       = local.firewall_private_ip
}

output "firewall_id" {
  description = "Azure Firewall resource ID."
  value       = azurerm_firewall.this.id
}

output "firewall_policy_id" {
  description = "Firewall policy ID, for attaching extra rule collection groups from outside this module."
  value       = azurerm_firewall_policy.this.id
}

output "spoke_dns_servers" {
  description = "DNS servers spokes should use: the firewall DNS proxy on Standard/Premium, Azure-provided DNS (empty list) on Basic."
  value       = local.dns_proxy_enabled ? [local.firewall_private_ip] : []
}

output "private_dns_zone_ids" {
  description = "Map of Private DNS zone name to resource ID."
  value       = { for name, zone in azurerm_private_dns_zone.this : name => zone.id }
}
