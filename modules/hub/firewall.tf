# ---------------------------------------------------------------------------
# Azure Firewall + Firewall Policy
# ---------------------------------------------------------------------------

resource "azurerm_firewall_policy" "this" {
  name                     = var.names["firewall_policy"]
  location                 = azurerm_resource_group.this.location
  resource_group_name      = azurerm_resource_group.this.name
  sku                      = var.firewall.sku_tier
  threat_intelligence_mode = var.firewall.sku_tier == "Basic" ? "Alert" : var.firewall.threat_intel_mode
  tags                     = var.tags

  dynamic "dns" {
    for_each = local.dns_proxy_enabled ? [1] : []
    content {
      proxy_enabled = true
    }
  }

  dynamic "intrusion_detection" {
    for_each = var.firewall.sku_tier == "Premium" ? [1] : []
    content {
      mode = var.firewall.idps_mode
    }
  }
}

resource "azurerm_firewall" "this" {
  name                = var.names["firewall"]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall.sku_tier
  firewall_policy_id  = azurerm_firewall_policy.this.id
  zones               = var.firewall.zones
  tags                = var.tags

  ip_configuration {
    name                 = "ipconfig-data"
    subnet_id            = azurerm_subnet.this["AzureFirewallSubnet"].id
    public_ip_address_id = azurerm_public_ip.this["firewall"].id
  }

  dynamic "management_ip_configuration" {
    for_each = local.needs_management_ip ? [1] : []
    content {
      name                 = "ipconfig-mgmt"
      subnet_id            = azurerm_subnet.this["AzureFirewallManagementSubnet"].id
      public_ip_address_id = azurerm_public_ip.this["firewall_mgmt"].id
    }
  }
}

# Platform rules every spoke needs. Anything not explicitly allowed is denied,
# which also gives spoke-to-spoke isolation by default.
resource "azurerm_firewall_policy_rule_collection_group" "platform" {
  name               = "rcg-platform"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 200

  network_rule_collection {
    name     = "allow-platform-network"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "ntp"
      protocols             = ["UDP"]
      source_addresses      = var.platform_source_addresses
      destination_addresses = ["*"]
      destination_ports     = ["123"]
    }
  }

  application_rule_collection {
    name     = "allow-platform-fqdns"
    priority = 200
    action   = "Allow"

    rule {
      name             = "azure-management-and-monitoring"
      source_addresses = var.platform_source_addresses
      destination_fqdns = [
        "management.azure.com",
        "login.microsoftonline.com",
        "*.ods.opinsights.azure.com",
        "*.oms.opinsights.azure.com",
        "*.monitoring.azure.com",
        "*.handler.control.monitor.azure.com",
      ]
      protocols {
        type = "Https"
        port = 443
      }
    }

    rule {
      name             = "os-updates"
      source_addresses = var.platform_source_addresses
      destination_fqdns = [
        "packages.microsoft.com",
        "*.ubuntu.com",
        "*.update.microsoft.com",
        "*.windowsupdate.com",
      ]
      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
    }
  }
}

# Workload egress generated from the spoke map: one rule per spoke, scoped to
# that spoke's own address space only.
resource "azurerm_firewall_policy_rule_collection_group" "workloads" {
  count = length(var.spoke_egress_rules) > 0 ? 1 : 0

  name               = "rcg-workloads"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 300

  application_rule_collection {
    name     = "allow-spoke-egress"
    priority = 100
    action   = "Allow"

    dynamic "rule" {
      for_each = var.spoke_egress_rules
      content {
        name              = "spoke-${rule.key}"
        source_addresses  = rule.value.source_addresses
        destination_fqdns = rule.value.destination_fqdns
        protocols {
          type = "Https"
          port = 443
        }
      }
    }
  }

  # The policy API accepts one rule collection group write at a time.
  depends_on = [azurerm_firewall_policy_rule_collection_group.platform]
}
