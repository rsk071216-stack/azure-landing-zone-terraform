# Production landing zone: zone-redundant Firewall Standard (DNS proxy,
# threat-intel deny), Bastion for break-glass access, 90-day log retention.

module "landing_zone" {
  source = "../../modules/landing-zone"

  environment     = "prod"
  location        = "westeurope"
  subscription_id = var.subscription_id

  tags = {
    owner       = "platform-team"
    cost_center = "cc-platform-001"
    repository  = "github.com/rsk071216-stack/azure-landing-zone-terraform"
  }

  hub = {
    address_space = "10.100.0.0/22"
    firewall = {
      sku_tier          = "Standard"
      zones             = ["1", "2", "3"]
      threat_intel_mode = "Deny"
    }
    bastion = {
      enabled = true
      sku     = "Standard"
    }
  }

  # Spoke vending: see spokes.tf
  spokes = local.spokes

  management = {
    log_retention_days    = 90
    enable_vnet_flow_logs = true
  }

  governance = {
    allowed_locations = ["westeurope", "northeurope"]
    enforce           = true
    subnet_nsg_effect = "Audit"
    budget = {
      amount         = 3000
      contact_emails = var.budget_contact_emails
    }
  }
}
