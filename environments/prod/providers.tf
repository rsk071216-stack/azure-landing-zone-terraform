provider "azurerm" {
  subscription_id = var.subscription_id

  # Entra ID for every storage data-plane call: no account keys anywhere.
  storage_use_azuread = true

  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    storage {
      # Private-only storage accounts are unreachable from a hosted CI runner;
      # skip data-plane reads so plans still work.
      data_plane_available = false
    }
  }
}
