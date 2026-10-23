# Landing-zone contract tests.
#
# These run the full composition (management + hub + N spokes + governance)
# against a mocked azurerm provider: real schema, fake API. They prove the
# architecture's invariants on every pull request without an Azure account.

mock_provider "azurerm" {
  source = "../../tests/mocks"
}

# azurerm checks that firewall and Bastion subnets carry their Azure-mandated
# names, so give those mocked subnet IDs the right last segment.
override_resource {
  target = module.hub.azurerm_subnet.this["AzureFirewallSubnet"]
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-mock/providers/Microsoft.Network/virtualNetworks/vnet-mock/subnets/AzureFirewallSubnet"
  }
}

override_resource {
  target = module.hub.azurerm_subnet.this["AzureFirewallManagementSubnet"]
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-mock/providers/Microsoft.Network/virtualNetworks/vnet-mock/subnets/AzureFirewallManagementSubnet"
  }
}

override_resource {
  target = module.hub.azurerm_subnet.this["AzureBastionSubnet"]
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-mock/providers/Microsoft.Network/virtualNetworks/vnet-mock/subnets/AzureBastionSubnet"
  }
}


variables {
  environment     = "dev"
  location        = "westeurope"
  subscription_id = "00000000-0000-0000-0000-000000000000"

  tags = {
    owner       = "platform-team"
    cost_center = "cc-1001"
  }

  hub = {
    address_space = "10.0.0.0/22"
  }

  spokes = {
    payments = {
      address_space                   = "10.10.0.0/22"
      egress_fqdns                    = ["api.stripe.com"]
      deploy_example_private_endpoint = true
      subnets = {
        app = { address_prefix = "10.10.0.0/24" }
        pe  = { address_prefix = "10.10.1.0/26", private_endpoints = true }
      }
    }
    analytics = {
      address_space = "10.20.0.0/22"
      subnets = {
        app = { address_prefix = "10.20.0.0/24" }
      }
    }
  }

  governance = {
    budget = { amount = 500, contact_emails = ["finops@example.com"] }
  }
}

run "every_spoke_routes_internet_through_the_firewall" {
  command = plan

  assert {
    condition     = output.hub.firewall_private_ip == "10.0.0.4"
    error_message = "Firewall IP must be the first usable host (.4) of AzureFirewallSubnet."
  }

  assert {
    condition = alltrue([
      for key, s in output.spokes :
      s.default_route.address_prefix == "0.0.0.0/0" &&
      s.default_route.next_hop_type == "VirtualAppliance" &&
      s.default_route.next_hop_in_ip_address == output.hub.firewall_private_ip
    ])
    error_message = "Every spoke must send 0.0.0.0/0 to the hub firewall private IP."
  }
}

run "hub_subnet_plan_is_deterministic" {
  command = plan

  assert {
    condition     = output.hub.subnet_prefixes["AzureFirewallSubnet"] == "10.0.0.0/26"
    error_message = "AzureFirewallSubnet must be the first /26 of the hub."
  }

  assert {
    condition     = output.hub.subnet_prefixes["AzureFirewallManagementSubnet"] == "10.0.0.64/26"
    error_message = "Basic SKU requires AzureFirewallManagementSubnet as the second /26."
  }

  assert {
    condition     = output.hub.subnet_prefixes["GatewaySubnet"] == "10.0.0.192/27"
    error_message = "GatewaySubnet must be reserved as a /27 for a future VPN/ExpressRoute gateway."
  }

  assert {
    condition     = !contains(keys(output.hub.subnet_prefixes), "AzureBastionSubnet")
    error_message = "Bastion is opt-in; its subnet must not exist when disabled."
  }
}

run "naming_convention_is_followed" {
  command = plan

  assert {
    condition = alltrue(flatten([
      for scope, names in output.resource_names : [
        for type, name in names : can(regex("^[a-z]+-${scope == "management" ? "mgmt" : scope}-dev-weu-001$", name))
        if !contains(["storage_account", "key_vault"], type)
      ]
    ]))
    error_message = "All names must follow <abbr>-<workload>-<env>-<region>-<instance>."
  }

  assert {
    condition     = output.spokes["payments"].virtual_network_name == "vnet-payments-dev-weu-001"
    error_message = "Spoke VNets must be named vnet-<spoke>-<env>-<region>-<instance>."
  }
}

run "required_tags_are_present" {
  command = plan

  assert {
    condition     = alltrue([for t in ["environment", "owner", "cost_center", "managed_by"] : contains(keys(output.required_tags), t)])
    error_message = "Baseline tags must include environment, owner, cost_center and managed_by."
  }
}

run "dns_proxy_used_only_when_sku_supports_it" {
  command = plan

  assert {
    condition     = length(output.hub.spoke_dns_servers) == 0
    error_message = "Basic SKU has no DNS proxy: spokes must use Azure-provided DNS."
  }
}

run "standard_sku_switches_spokes_to_firewall_dns_proxy" {
  command = plan

  variables {
    hub = {
      address_space = "10.0.0.0/22"
      firewall      = { sku_tier = "Standard" }
    }
  }

  assert {
    condition     = output.hub.spoke_dns_servers == tolist(["10.0.0.4"])
    error_message = "With DNS proxy available, spokes must resolve through the firewall."
  }

  assert {
    condition     = !contains(keys(output.hub.subnet_prefixes), "AzureFirewallManagementSubnet")
    error_message = "Standard SKU does not need a management subnet."
  }
}

run "rejects_overlapping_spokes" {
  command = plan

  variables {
    spokes = {
      one = {
        address_space = "10.10.0.0/22"
        subnets       = { app = { address_prefix = "10.10.0.0/24" } }
      }
      two = {
        address_space = "10.10.2.0/24"
        subnets       = { app = { address_prefix = "10.10.2.0/25" } }
      }
    }
  }

  expect_failures = [var.spokes]
}

run "rejects_spoke_overlapping_hub" {
  command = plan

  variables {
    spokes = {
      clash = {
        address_space = "10.0.2.0/24"
        subnets       = { app = { address_prefix = "10.0.2.0/25" } }
      }
    }
  }

  expect_failures = [terraform_data.guardrails]
}

run "rejects_missing_required_tag" {
  command = plan

  variables {
    tags = { owner = "platform-team" }
  }

  expect_failures = [terraform_data.guardrails]
}

run "rejects_invalid_spoke_key" {
  command = plan

  variables {
    spokes = {
      "Team_A" = {
        address_space = "10.30.0.0/24"
        subnets       = { app = { address_prefix = "10.30.0.0/25" } }
      }
    }
  }

  expect_failures = [var.spokes]
}

run "full_landing_zone_applies_against_mocks" {
  command = apply

  variables {
    hub = {
      address_space = "10.0.0.0/22"
      bastion       = { enabled = true }
    }
  }

  assert {
    condition     = length(output.spokes) == 2
    error_message = "Both spokes must be vended."
  }

  assert {
    condition     = alltrue([for k, pe in output.example_private_endpoints : pe.public_network_access_enabled == false])
    error_message = "Every example private endpoint target must have public network access disabled."
  }

  assert {
    condition     = length(output.policy_assignment_ids) == 13
    error_message = "Expected 6 baseline + 1 DNS + 3 require-tag + 3 inherit-tag policy assignments."
  }
}
