# Development landing zone: cost-optimised (Firewall Basic, no Bastion,
# 1 GB/day log cap) but architecturally identical to production.

module "landing_zone" {
  source = "../../modules/landing-zone"

  environment     = "dev"
  location        = "westeurope"
  subscription_id = var.subscription_id

  tags = {
    owner       = "platform-team"
    cost_center = "cc-platform-001"
    repository  = "github.com/rsk071216-stack/azure-landing-zone-terraform"
  }

  hub = {
    address_space = "10.0.0.0/22"
    firewall      = { sku_tier = "Basic" }
    bastion       = { enabled = false }
  }

  # Spoke vending: see spokes.tf
  spokes = local.spokes

  management = {
    log_retention_days    = 30
    log_daily_quota_gb    = 1
    enable_vnet_flow_logs = true
  }

  governance = {
    allowed_locations = ["westeurope", "northeurope"]
    enforce           = true
    subnet_nsg_effect = "Audit"
    budget = {
      amount         = 400
      contact_emails = var.budget_contact_emails
    }
  }
}
