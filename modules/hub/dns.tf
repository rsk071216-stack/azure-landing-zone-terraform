# ---------------------------------------------------------------------------
# Centralised Private Link DNS. Zones exist once, in the hub; every spoke links
# to them (see the spoke module), so private endpoints resolve identically from
# any VNet. A governance policy blocks teams from creating rogue copies.
# ---------------------------------------------------------------------------

resource "azurerm_private_dns_zone" "this" {
  for_each = var.private_dns_zones

  name                = each.key
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  for_each = var.private_dns_zones

  name                  = "link-${azurerm_virtual_network.this.name}"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.key].name
  virtual_network_id    = azurerm_virtual_network.this.id
  registration_enabled  = false
  tags                  = var.tags
}
