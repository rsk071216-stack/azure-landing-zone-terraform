# ---------------------------------------------------------------------------
# Spoke vending (prod). Address plan: hub 10.100.0.0/22, spokes 10.1<n>.0.0/22.
# ---------------------------------------------------------------------------

locals {
  spokes = {
    payments = {
      address_space                   = "10.110.0.0/22"
      egress_fqdns                    = ["api.stripe.com"]
      deploy_example_private_endpoint = true
      tags                            = { data_classification = "confidential" }

      subnets = {
        app = {
          address_prefix = "10.110.0.0/24"
          nsg_rules = {
            allow-https-from-hub = {
              priority                     = 100
              direction                    = "Inbound"
              access                       = "Allow"
              protocol                     = "Tcp"
              source_address_prefixes      = ["10.100.0.0/22"]
              destination_address_prefixes = ["10.110.0.0/24"]
              destination_port_ranges      = ["443"]
            }
          }
        }
        data = { address_prefix = "10.110.1.0/24" }
        pe   = { address_prefix = "10.110.2.0/26", private_endpoints = true }
      }
    }

    analytics = {
      address_space = "10.120.0.0/22"
      egress_fqdns  = ["pypi.org", "files.pythonhosted.org"]

      subnets = {
        app = { address_prefix = "10.120.0.0/24" }
        pe  = { address_prefix = "10.120.1.0/26", private_endpoints = true }
      }
    }
  }
}
