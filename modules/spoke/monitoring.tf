locals {
  diagnostic_targets = merge(
    { virtual_network = azurerm_virtual_network.this.id },
    { for key, nsg in azurerm_network_security_group.this : "nsg_${key}" => nsg.id },
  )
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = local.diagnostic_targets

  name                       = "diag-to-law"
  target_resource_id         = each.value
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  # NSGs expose no platform metrics.
  dynamic "enabled_metric" {
    for_each = each.key == "virtual_network" ? [1] : []
    content {
      category = "AllMetrics"
    }
  }
}

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
