# ---------------------------------------------------------------------------
# Reference private endpoint: a Storage Account with no public surface,
# reachable only from inside the network via privatelink.blob.core.windows.net.
# ---------------------------------------------------------------------------

locals {
  blob_zone_name = "privatelink.blob.core.windows.net"
}

resource "azurerm_storage_account" "example" {
  count = var.deploy_example_private_endpoint ? 1 : 0

  #checkov:skip=CKV2_AZURE_1:Customer-managed keys are out of scope for the reference workload (see docs/adr/0004).
  #checkov:skip=CKV_AZURE_206:LRS is deliberate for a disposable reference workload.
  #checkov:skip=CKV2_AZURE_40:Shared key access is disabled below; check misfires on azurerm 4.x attribute names.

  name                              = var.names["storage_account"]
  location                          = azurerm_resource_group.this.location
  resource_group_name               = azurerm_resource_group.this.name
  account_tier                      = "Standard"
  account_replication_type          = "LRS"
  account_kind                      = "StorageV2"
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  public_network_access_enabled     = false
  shared_access_key_enabled         = false
  default_to_oauth_authentication   = true
  allow_nested_items_to_be_public   = false
  cross_tenant_replication_enabled  = false
  infrastructure_encryption_enabled = true
  tags                              = var.tags

  network_rules {
    default_action = "Deny"
    bypass         = ["None"]
  }

  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  lifecycle {
    precondition {
      condition     = length(local.private_endpoint_subnets) > 0
      error_message = "deploy_example_private_endpoint requires one subnet with private_endpoints = true."
    }
    precondition {
      condition     = contains(keys(var.private_dns_zone_ids), local.blob_zone_name)
      error_message = "The central Private DNS zone ${local.blob_zone_name} must be passed in private_dns_zone_ids."
    }
  }
}

resource "azurerm_private_endpoint" "example_blob" {
  count = var.deploy_example_private_endpoint ? 1 : 0

  name                          = "${var.names["private_endpoint"]}-blob"
  location                      = azurerm_resource_group.this.location
  resource_group_name           = azurerm_resource_group.this.name
  subnet_id                     = azurerm_subnet.this[local.private_endpoint_subnets[0]].id
  custom_network_interface_name = "${var.names["private_endpoint"]}-blob-nic"
  tags                          = var.tags

  private_service_connection {
    name                           = "psc-blob"
    private_connection_resource_id = azurerm_storage_account.example[0].id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  # Registers the A record in the hub-hosted zone automatically.
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_dns_zone_ids[local.blob_zone_name]]
  }

  # Links must exist before the endpoint so the name resolves immediately.
  depends_on = [azurerm_private_dns_zone_virtual_network_link.this]
}
