output "resource_group_name" {
  description = "Spoke resource group name."
  value       = azurerm_resource_group.this.name
}

output "virtual_network_id" {
  description = "Spoke VNet resource ID."
  value       = azurerm_virtual_network.this.id
}

output "virtual_network_name" {
  description = "Spoke VNet name."
  value       = azurerm_virtual_network.this.name
}

output "address_space" {
  description = "Spoke VNet CIDR."
  value       = var.address_space
}

output "subnet_ids" {
  description = "Map of subnet key to subnet ID."
  value       = { for key, subnet in azurerm_subnet.this : key => subnet.id }
}

output "network_security_group_ids" {
  description = "Map of subnet key to the ID of the NSG protecting it."
  value       = { for key, nsg in azurerm_network_security_group.this : key => nsg.id }
}

output "default_route" {
  description = "The forced-tunnelling route installed on every subnet."
  value = {
    address_prefix         = azurerm_route.default.address_prefix
    next_hop_type          = azurerm_route.default.next_hop_type
    next_hop_in_ip_address = azurerm_route.default.next_hop_in_ip_address
  }
}

output "example_storage_account" {
  description = "Reference private-only Storage Account, or null when not deployed."
  value = var.deploy_example_private_endpoint ? {
    id                            = azurerm_storage_account.example[0].id
    name                          = azurerm_storage_account.example[0].name
    public_network_access_enabled = azurerm_storage_account.example[0].public_network_access_enabled
    private_endpoint_id           = azurerm_private_endpoint.example_blob[0].id
  } : null
}
