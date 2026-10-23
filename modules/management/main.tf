resource "azurerm_resource_group" "this" {
  name     = var.names["resource_group"]
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                         = var.names["log_analytics"]
  location                     = azurerm_resource_group.this.location
  resource_group_name          = azurerm_resource_group.this.name
  sku                          = "PerGB2018"
  retention_in_days            = var.log_retention_days
  daily_quota_gb               = var.log_daily_quota_gb
  local_authentication_enabled = false # Entra ID only; agents use managed identity (AMA)
  tags                         = var.tags
}

# ---------------------------------------------------------------------------
# VNet flow logs: storage account (mandatory sink) + Network Watcher
# ---------------------------------------------------------------------------

# tflint-ignore: azurerm_resources_missing_prevent_destroy # flow logs are disposable telemetry; prevent_destroy would block the documented teardown
resource "azurerm_storage_account" "flow_logs" {
  #checkov:skip=CKV2_AZURE_1:Customer-managed keys are out of scope for the reference build (see docs/adr/0004).
  #checkov:skip=CKV_AZURE_33:Queue service is not used by flow logs.
  #checkov:skip=CKV_AZURE_59:Public endpoint is required for the trusted-service write path; network_rules default to Deny.
  count = var.enable_vnet_flow_logs ? 1 : 0

  name                             = var.names["storage_account"]
  location                         = azurerm_resource_group.this.location
  resource_group_name              = azurerm_resource_group.this.name
  account_tier                     = "Standard"
  account_replication_type         = "ZRS"
  account_kind                     = "StorageV2"
  min_tls_version                  = "TLS1_2"
  https_traffic_only_enabled       = true
  allow_nested_items_to_be_public  = false
  public_network_access_enabled    = true # Network Watcher writes as a trusted Microsoft service; data plane is still locked by network_rules
  default_to_oauth_authentication  = true
  cross_tenant_replication_enabled = false
  tags                             = var.tags

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices", "Logging", "Metrics"]
  }

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }
}

resource "azurerm_network_watcher" "this" {
  count = var.network_watcher.create ? 1 : 0

  name                = var.names["network_watcher"]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

locals {
  network_watcher_name = var.network_watcher.create ? azurerm_network_watcher.this[0].name : coalesce(var.network_watcher.name, "NetworkWatcher_${var.location}")
  network_watcher_rg   = var.network_watcher.create ? azurerm_network_watcher.this[0].resource_group_name : var.network_watcher.resource_group_name
}
