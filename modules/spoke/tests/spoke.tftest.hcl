# Unit tests for the spoke vending module.
# mock_provider means no Azure credentials, no subscription and no cost:
# Terraform loads the real azurerm schema but fakes every API response.

mock_provider "azurerm" {
  source = "../../tests/mocks"
}

variables {
  location = "westeurope"

  names = {
    resource_group         = "rg-payments-dev-weu-001"
    virtual_network        = "vnet-payments-dev-weu-001"
    subnet                 = "snet-payments-dev-weu-001"
    network_security_group = "nsg-payments-dev-weu-001"
    route_table            = "rt-payments-dev-weu-001"
    vnet_peering           = "peer-payments-dev-weu-001"
    vnet_flow_log          = "fl-payments-dev-weu-001"
    private_endpoint       = "pep-payments-dev-weu-001"
    storage_account        = "stpaymentsdevweu1a2b3c"
  }

  tags = {
    environment = "dev"
    owner       = "platform-team"
    cost_center = "cc-1001"
  }

  address_space = "10.10.0.0/22"

  subnets = {
    app = { address_prefix = "10.10.0.0/24" }
    pe  = { address_prefix = "10.10.1.0/26", private_endpoints = true }
  }

  hub = {
    virtual_network_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-dev-weu-001/providers/Microsoft.Network/virtualNetworks/vnet-hub-dev-weu-001"
    virtual_network_name = "vnet-hub-dev-weu-001"
    resource_group_name  = "rg-hub-dev-weu-001"
    firewall_private_ip  = "10.0.0.4"
  }

  private_dns_zone_ids = {
    "privatelink.blob.core.windows.net" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-dev-weu-001/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
  }

  deploy_example_private_endpoint = true
  log_analytics_workspace_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-mgmt-dev-weu-001/providers/Microsoft.OperationalInsights/workspaces/log-mgmt-dev-weu-001"
}

run "default_route_points_to_firewall" {
  command = plan

  assert {
    condition     = azurerm_route.default.address_prefix == "0.0.0.0/0" && azurerm_route.default.next_hop_type == "VirtualAppliance"
    error_message = "The spoke must send 0.0.0.0/0 to a virtual appliance."
  }

  assert {
    condition     = azurerm_route.default.next_hop_in_ip_address == var.hub.firewall_private_ip
    error_message = "The default route must point at the hub firewall private IP."
  }

  assert {
    condition     = azurerm_route_table.this.bgp_route_propagation_enabled == false
    error_message = "BGP route propagation must be disabled so on-premises routes cannot bypass the firewall."
  }

  assert {
    condition     = length(azurerm_subnet_route_table_association.this) == length(var.subnets)
    error_message = "Every subnet must be associated with the forced-tunnelling route table."
  }
}

run "every_subnet_has_an_nsg" {
  command = plan

  assert {
    condition     = toset(keys(azurerm_subnet_network_security_group_association.this)) == toset(keys(var.subnets))
    error_message = "Every subnet must have an NSG association."
  }

  assert {
    condition     = alltrue([for r in azurerm_network_security_rule.deny_internet_inbound : r.access == "Deny" && r.source_address_prefix == "Internet"])
    error_message = "Every NSG must carry the baseline deny-internet-inbound rule."
  }

  assert {
    condition     = alltrue([for s in azurerm_subnet.this : s.default_outbound_access_enabled == false])
    error_message = "Default outbound internet access must be disabled on every subnet."
  }
}

run "private_endpoint_has_no_public_access" {
  command = plan

  assert {
    condition     = azurerm_storage_account.example[0].public_network_access_enabled == false
    error_message = "The Storage Account behind the private endpoint must not be publicly reachable."
  }

  assert {
    condition     = azurerm_storage_account.example[0].shared_access_key_enabled == false
    error_message = "Shared key auth must be disabled; access is Entra ID only."
  }

  assert {
    condition     = azurerm_storage_account.example[0].min_tls_version == "TLS1_2"
    error_message = "Minimum TLS version must be 1.2."
  }

  assert {
    condition     = azurerm_private_endpoint.example_blob[0].private_dns_zone_group[0].private_dns_zone_ids[0] == var.private_dns_zone_ids["privatelink.blob.core.windows.net"]
    error_message = "The private endpoint must register in the central hub DNS zone, not a local copy."
  }
}

run "peering_is_bidirectional_and_allows_forwarded_traffic" {
  command = plan

  assert {
    condition     = azurerm_virtual_network_peering.spoke_to_hub.allow_forwarded_traffic && azurerm_virtual_network_peering.hub_to_spoke.allow_forwarded_traffic
    error_message = "Both peering directions must allow forwarded traffic (firewall return path)."
  }

  assert {
    condition     = azurerm_virtual_network_peering.hub_to_spoke.resource_group_name == var.hub.resource_group_name
    error_message = "The hub-side peering must be created in the hub resource group."
  }
}

run "required_tags_on_every_taggable_resource" {
  command = plan

  assert {
    condition = alltrue([
      for t in concat(
        [azurerm_resource_group.this.tags, azurerm_virtual_network.this.tags, azurerm_route_table.this.tags],
        [for nsg in azurerm_network_security_group.this : nsg.tags],
      ) : alltrue([for k in ["environment", "owner", "cost_center"] : contains(keys(t), k)])
    ])
    error_message = "Resource groups, VNets, route tables and NSGs must carry environment, owner and cost_center tags."
  }
}

run "rejects_overlapping_subnets" {
  command = plan

  variables {
    subnets = {
      app  = { address_prefix = "10.10.0.0/24" }
      data = { address_prefix = "10.10.0.128/25" }
    }
    deploy_example_private_endpoint = false
  }

  expect_failures = [var.subnets]
}

run "rejects_subnet_outside_address_space" {
  command = plan

  variables {
    subnets = {
      app = { address_prefix = "10.99.0.0/24" }
    }
    deploy_example_private_endpoint = false
  }

  expect_failures = [azurerm_virtual_network.this]
}

run "full_graph_applies_against_mocks" {
  # apply against the mock provider: exercises every resource and output
  # with fake computed values, still with zero Azure calls.
  command = apply

  assert {
    condition     = output.example_storage_account.public_network_access_enabled == false
    error_message = "The example storage account output must confirm public access is disabled."
  }

  assert {
    condition     = length(output.subnet_ids) == 2
    error_message = "Both subnets must be created."
  }
}
