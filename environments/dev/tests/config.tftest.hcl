# Tests the real environment configuration (not a fixture): the address plan,
# routing and private-endpoint settings that would actually be deployed.

mock_provider "azurerm" {
  source = "../../tests/mocks"
}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

run "environment_contract" {
  command = plan

  assert {
    condition = alltrue([
      for key, s in output.spokes : s.default_route.next_hop_in_ip_address == output.hub.firewall_private_ip
    ])
    error_message = "Every spoke must route 0.0.0.0/0 through the hub firewall."
  }

  assert {
    condition     = length(output.spokes) == length(local.spokes)
    error_message = "Every entry in spokes.tf must produce a spoke."
  }
}
