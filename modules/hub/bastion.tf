resource "azurerm_bastion_host" "this" {
  count = var.bastion.enabled ? 1 : 0

  name                   = var.names["bastion"]
  location               = azurerm_resource_group.this.location
  resource_group_name    = azurerm_resource_group.this.name
  sku                    = var.bastion.sku
  copy_paste_enabled     = true
  file_copy_enabled      = var.bastion.sku != "Basic"
  tunneling_enabled      = var.bastion.sku != "Basic"
  shareable_link_enabled = false
  tags                   = var.tags

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.this["AzureBastionSubnet"].id
    public_ip_address_id = azurerm_public_ip.this["bastion"].id
  }
}
