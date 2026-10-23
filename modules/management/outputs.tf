output "resource_group_name" {
  description = "Management resource group name."
  value       = azurerm_resource_group.this.name
}

output "log_analytics_workspace_id" {
  description = "Azure resource ID of the central Log Analytics workspace (diagnostic settings target)."
  value       = azurerm_log_analytics_workspace.this.id
}

output "log_analytics_workspace_guid" {
  description = "Workspace (customer) ID, required by traffic analytics."
  value       = azurerm_log_analytics_workspace.this.workspace_id
}

output "flow_log_settings" {
  description = "Settings consumed by hub and spoke modules to create VNet flow logs; null when flow logs are disabled."
  value = var.enable_vnet_flow_logs ? {
    network_watcher_name                = local.network_watcher_name
    network_watcher_resource_group_name = local.network_watcher_rg
    storage_account_id                  = azurerm_storage_account.flow_logs[0].id
    workspace_guid                      = azurerm_log_analytics_workspace.this.workspace_id
    workspace_resource_id               = azurerm_log_analytics_workspace.this.id
    workspace_location                  = azurerm_log_analytics_workspace.this.location
    retention_days                      = 30
  } : null
}

output "resource_group_id" {
  description = "Management resource group ID."
  value       = azurerm_resource_group.this.id
}
