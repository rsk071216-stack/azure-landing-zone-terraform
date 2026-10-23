locals {
  prefix_length = tonumber(split("/", var.address_space)[1])

  # Deterministic platform subnet plan: four /26 blocks at the start of the hub range.
  #   0: AzureFirewallSubnet   1: AzureFirewallManagementSubnet
  #   2: AzureBastionSubnet    3: GatewaySubnet (/27, upper half kept free)
  # Everything after the first /24 stays available for shared services.
  subnet_plan = {
    AzureFirewallSubnet           = cidrsubnet(var.address_space, 26 - local.prefix_length, 0)
    AzureFirewallManagementSubnet = cidrsubnet(var.address_space, 26 - local.prefix_length, 1)
    AzureBastionSubnet            = cidrsubnet(var.address_space, 26 - local.prefix_length, 2)
    GatewaySubnet                 = cidrsubnet(var.address_space, 27 - local.prefix_length, 6)
  }

  # Azure Firewall always takes the first usable host (.4) of AzureFirewallSubnet.
  # Computing it (instead of reading it back from the firewall) lets every spoke
  # build its route table in parallel with the 10+ minute firewall deployment.
  firewall_private_ip = cidrhost(local.subnet_plan.AzureFirewallSubnet, 4)

  # The Basic SKU requires a dedicated management NIC; Standard/Premium do not.
  needs_management_ip = var.firewall.sku_tier == "Basic"

  # DNS proxy (and FQDNs in network rules) are not available on the Basic SKU.
  dns_proxy_enabled = var.firewall.sku_tier != "Basic"

  subnets = merge(
    { AzureFirewallSubnet = local.subnet_plan.AzureFirewallSubnet },
    local.needs_management_ip ? { AzureFirewallManagementSubnet = local.subnet_plan.AzureFirewallManagementSubnet } : {},
    var.bastion.enabled ? { AzureBastionSubnet = local.subnet_plan.AzureBastionSubnet } : {},
    var.create_gateway_subnet ? { GatewaySubnet = local.subnet_plan.GatewaySubnet } : {},
  )

  public_ips = merge(
    { firewall = "${var.names["public_ip"]}-afw" },
    local.needs_management_ip ? { firewall_mgmt = "${var.names["public_ip"]}-afw-mgmt" } : {},
    var.bastion.enabled ? { bastion = "${var.names["public_ip"]}-bas" } : {},
  )
}

resource "azurerm_resource_group" "this" {
  name     = var.names["resource_group"]
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Hub virtual network
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network" "this" {
  name                = var.names["virtual_network"]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  for_each = local.subnets

  name                            = each.key
  resource_group_name             = azurerm_resource_group.this.name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = [each.value]
  default_outbound_access_enabled = false
}

resource "azurerm_public_ip" "this" {
  for_each = local.public_ips

  name                = each.value
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.firewall.zones
  tags                = var.tags
}
