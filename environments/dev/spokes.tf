# ---------------------------------------------------------------------------
# Spoke vending
#
# One entry = one workload landing zone: resource group, VNet, subnets with
# NSGs, 0.0.0.0/0 via the hub firewall, hub peering, central Private DNS
# links, a firewall egress rule, VNet flow logs and diagnostics.
#
# Address plan (dev): hub 10.0.0.0/22, spokes 10.<n>.0.0/22.
# Overlaps are rejected at plan time by validation and tests.
# ---------------------------------------------------------------------------

locals {
  spokes = {
    payments = {
      address_space                   = "10.10.0.0/22"
      egress_fqdns                    = ["api.stripe.com"]
      deploy_example_private_endpoint = true
      tags                            = { data_classification = "confidential" }

      subnets = {
        app = {
          address_prefix = "10.10.0.0/24"
          nsg_rules = {
            allow-https-from-hub = {
              priority                     = 100
              direction                    = "Inbound"
              access                       = "Allow"
              protocol                     = "Tcp"
              source_address_prefixes      = ["10.0.0.0/22"]
              destination_address_prefixes = ["10.10.0.0/24"]
              destination_port_ranges      = ["443"]
            }
          }
        }
        data = { address_prefix = "10.10.1.0/24" }
        pe   = { address_prefix = "10.10.2.0/26", private_endpoints = true }
      }
    }

    analytics = {
      address_space = "10.20.0.0/22"
      egress_fqdns  = ["pypi.org", "files.pythonhosted.org"]

      subnets = {
        app = { address_prefix = "10.20.0.0/24" }
        pe  = { address_prefix = "10.20.1.0/26", private_endpoints = true }
      }
    }
  }
}
