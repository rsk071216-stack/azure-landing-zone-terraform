locals {
  space_prefix = tonumber(split("/", var.address_space)[1])

  # Subnets that fall outside the spoke address space (checked by a precondition on the VNet).
  subnets_outside_space = [
    for key, s in var.subnets : key
    if tonumber(split("/", s.address_prefix)[1]) < local.space_prefix ||
    cidrhost("${split("/", s.address_prefix)[0]}/${local.space_prefix}", 0) != cidrhost(var.address_space, 0)
  ]

  private_endpoint_subnets = [for key, s in var.subnets : key if s.private_endpoints]

  nsg_rules = merge([
    for subnet_key, s in var.subnets : {
      for rule_key, rule in s.nsg_rules : "${subnet_key}.${rule_key}" => merge(rule, {
        subnet_key = subnet_key
        name       = rule_key
      })
    }
  ]...)
}

resource "azurerm_resource_group" "this" {
  name     = var.names["resource_group"]
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Virtual network and subnets
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network" "this" {
  name                = var.names["virtual_network"]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.address_space]
  dns_servers         = var.dns_servers
  tags                = var.tags

  lifecycle {
    precondition {
      condition     = length(local.subnets_outside_space) == 0
      error_message = "Subnets ${join(", ", local.subnets_outside_space)} are not inside the spoke address space ${var.address_space}."
    }
  }
}

resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                 = "${var.names["subnet"]}-${each.key}"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [each.value.address_prefix]
  service_endpoints    = each.value.service_endpoints

  # No implicit internet egress: everything leaves through the hub firewall.
  default_outbound_access_enabled = false

  # Make NSGs and UDRs apply to private endpoint traffic as well.
  private_endpoint_network_policies = "Enabled"

  dynamic "delegation" {
    for_each = each.value.delegation == null ? [] : [each.value.delegation]
    content {
      name = delegation.value.name
      service_delegation {
        name    = delegation.value.service
        actions = delegation.value.actions
      }
    }
  }
}

# ---------------------------------------------------------------------------
# NSG per subnet: baseline deny from Internet + caller-supplied rules
# ---------------------------------------------------------------------------

resource "azurerm_network_security_group" "this" {
  for_each = var.subnets

  name                = "${var.names["network_security_group"]}-${each.key}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "deny_internet_inbound" {
  for_each = var.subnets

  name                        = "deny-internet-inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_address_prefix       = "Internet"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.this[each.key].name
}

resource "azurerm_network_security_rule" "custom" {
  for_each = local.nsg_rules

  name                         = each.value.name
  priority                     = each.value.priority
  direction                    = each.value.direction
  access                       = each.value.access
  protocol                     = each.value.protocol
  source_address_prefixes      = each.value.source_address_prefixes
  source_port_range            = "*"
  destination_address_prefixes = each.value.destination_address_prefixes
  destination_port_ranges      = each.value.destination_port_ranges
  resource_group_name          = azurerm_resource_group.this.name
  network_security_group_name  = azurerm_network_security_group.this[each.value.subnet_key].name
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = var.subnets

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

# ---------------------------------------------------------------------------
# Forced tunnelling: 0.0.0.0/0 -> hub firewall for every subnet
# ---------------------------------------------------------------------------

resource "azurerm_route_table" "this" {
  name                = var.names["route_table"]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  # Stop gateway-learned (on-premises) routes from bypassing the firewall.
  bgp_route_propagation_enabled = false
}

resource "azurerm_route" "default" {
  name                   = "default-via-hub-firewall"
  resource_group_name    = azurerm_resource_group.this.name
  route_table_name       = azurerm_route_table.this.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.hub.firewall_private_ip
}

resource "azurerm_subnet_route_table_association" "this" {
  for_each = var.subnets

  subnet_id      = azurerm_subnet.this[each.key].id
  route_table_id = azurerm_route_table.this.id
}

# ---------------------------------------------------------------------------
# Hub <-> spoke peering (both directions are owned by the spoke, so adding or
# removing a spoke never requires touching hub code)
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "${var.names["vnet_peering"]}-to-hub"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = azurerm_virtual_network.this.name
  remote_virtual_network_id    = var.hub.virtual_network_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "${var.names["vnet_peering"]}-from-hub"
  resource_group_name          = var.hub.resource_group_name
  virtual_network_name         = var.hub.virtual_network_name
  remote_virtual_network_id    = azurerm_virtual_network.this.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# ---------------------------------------------------------------------------
# Link the spoke to every central Private DNS zone
# ---------------------------------------------------------------------------

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = var.private_dns_zone_ids

  name                  = "link-${azurerm_virtual_network.this.name}"
  resource_group_name   = var.hub.resource_group_name
  private_dns_zone_name = each.key
  virtual_network_id    = azurerm_virtual_network.this.id
  registration_enabled  = false
  tags                  = var.tags
}
