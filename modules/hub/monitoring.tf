locals {
  # Keys are static (known at plan time) so for_each works before resources exist.
  diagnostic_targets = merge(
    {
      firewall        = azurerm_firewall.this.id
      virtual_network = azurerm_virtual_network.this.id
    },
    { for key, pip in azurerm_public_ip.this : "pip_${key}" => pip.id },
    var.bastion.enabled ? { bastion = azurerm_bastion_host.this[0].id } : {},
  )
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = local.diagnostic_targets

  name               = "diag-to-law"
  target_resource_id = each.value

  log_analytics_workspace_id = var.log_analytics_workspace_id
  # Resource-specific tables (AZFWNetworkRule, AZFWApplicationRule, ...) are
  # cheaper to query and retain than the legacy AzureDiagnostics table.
  log_analytics_destination_type = each.key == "firewall" ? "Dedicated" : null

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# VNet flow logs replace NSG flow logs (retired by Microsoft for new deployments).
resource "azurerm_network_watcher_flow_log" "this" {
  count = var.flow_log_settings != null ? 1 : 0

  name                 = "${var.names["vnet_flow_log"]}-vnet"
  network_watcher_name = var.flow_log_settings.network_watcher_name
  resource_group_name  = var.flow_log_settings.network_watcher_resource_group_name
  location             = var.location
  target_resource_id   = azurerm_virtual_network.this.id
  storage_account_id   = var.flow_log_settings.storage_account_id
  enabled              = true
  version              = 2
  tags                 = var.tags

  retention_policy {
    enabled = true
    days    = var.flow_log_settings.retention_days
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = var.flow_log_settings.workspace_guid
    workspace_region      = var.flow_log_settings.workspace_location
    workspace_resource_id = var.flow_log_settings.workspace_resource_id
    interval_in_minutes   = 10
  }
}
