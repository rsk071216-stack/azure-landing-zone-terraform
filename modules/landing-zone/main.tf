locals {
  tags = merge(var.tags, {
    environment = var.environment
    managed_by  = "terraform"
  })

  # Every CIDR in the landing zone, used by the overlap guardrail below.
  hub_ip     = split("/", var.hub.address_space)[0]
  hub_prefix = tonumber(split("/", var.hub.address_space)[1])

  spokes_overlapping_hub = [
    for key, s in var.spokes : key
    if cidrhost("${local.hub_ip}/${min(local.hub_prefix, tonumber(split("/", s.address_space)[1]))}", 0) ==
    cidrhost("${split("/", s.address_space)[0]}/${min(local.hub_prefix, tonumber(split("/", s.address_space)[1]))}", 0)
  ]

  missing_required_tags = [
    for tag in var.governance.required_tags : tag if !contains(keys(local.tags), tag)
  ]

  # Firewall egress allow-list generated from the spoke map.
  spoke_egress_rules = {
    for key, s in var.spokes : key => {
      source_addresses  = [s.address_space]
      destination_fqdns = s.egress_fqdns
    } if length(s.egress_fqdns) > 0
  }
}

# Cross-variable guardrails. Variable validation can only see one variable at a
# time on Terraform < 1.9, so checks that span inputs live here and fail the plan.
resource "terraform_data" "guardrails" {
  lifecycle {
    precondition {
      condition     = length(local.spokes_overlapping_hub) == 0
      error_message = "Spokes ${join(", ", local.spokes_overlapping_hub)} overlap the hub address space ${var.hub.address_space}."
    }

    precondition {
      condition     = length(local.missing_required_tags) == 0
      error_message = "tags is missing required tag(s): ${join(", ", local.missing_required_tags)}."
    }
  }
}

# ---------------------------------------------------------------------------
# Naming (one scope per component)
# ---------------------------------------------------------------------------

module "naming_management" {
  source = "../naming"

  workload    = "mgmt"
  environment = var.environment
  location    = var.location
  unique_seed = var.subscription_id
}

module "naming_hub" {
  source = "../naming"

  workload    = "hub"
  environment = var.environment
  location    = var.location
  unique_seed = var.subscription_id
}

module "naming_spoke" {
  source   = "../naming"
  for_each = var.spokes

  workload    = each.key
  environment = var.environment
  location    = var.location
  unique_seed = var.subscription_id
}

# ---------------------------------------------------------------------------
# Platform: management, connectivity, governance
# ---------------------------------------------------------------------------

module "management" {
  source = "../management"

  names                 = module.naming_management.names
  location              = var.location
  tags                  = merge(local.tags, { workload = "management" })
  log_retention_days    = var.management.log_retention_days
  log_daily_quota_gb    = var.management.log_daily_quota_gb
  enable_vnet_flow_logs = var.management.enable_vnet_flow_logs
  network_watcher       = var.management.network_watcher
}

module "hub" {
  source = "../hub"

  names                      = module.naming_hub.names
  location                   = var.location
  tags                       = merge(local.tags, { workload = "connectivity" })
  address_space              = var.hub.address_space
  firewall                   = var.hub.firewall
  bastion                    = var.hub.bastion
  create_gateway_subnet      = var.hub.create_gateway_subnet
  private_dns_zones          = var.hub.private_dns_zones
  spoke_egress_rules         = local.spoke_egress_rules
  log_analytics_workspace_id = module.management.log_analytics_workspace_id
  flow_log_settings          = module.management.flow_log_settings
}

module "governance" {
  source = "../governance"
  count  = var.governance.enabled ? 1 : 0

  subscription_id               = var.subscription_id
  name_prefix                   = "alz-${var.environment}"
  location                      = var.location
  allowed_locations             = coalesce(var.governance.allowed_locations, [var.location])
  required_tags                 = var.governance.required_tags
  enforce                       = var.governance.enforce
  subnet_nsg_effect             = var.governance.subnet_nsg_effect
  storage_public_access_effect  = var.governance.storage_public_access_effect
  central_dns_resource_group_id = module.hub.resource_group_id
  budget                        = var.governance.budget

  storage_public_access_exemptions = var.management.enable_vnet_flow_logs ? {
    flowlogs = module.management.resource_group_id
  } : {}
}

# ---------------------------------------------------------------------------
# Spoke vending: one map entry in var.spokes = one landing zone for a team
# ---------------------------------------------------------------------------

module "spoke" {
  source   = "../spoke"
  for_each = var.spokes

  names         = module.naming_spoke[each.key].names
  location      = var.location
  tags          = merge(local.tags, { workload = each.key }, each.value.tags)
  address_space = each.value.address_space
  subnets       = each.value.subnets
  dns_servers   = module.hub.spoke_dns_servers

  hub = {
    virtual_network_id   = module.hub.virtual_network_id
    virtual_network_name = module.hub.virtual_network_name
    resource_group_name  = module.hub.resource_group_name
    firewall_private_ip  = module.hub.firewall_private_ip
  }

  private_dns_zone_ids            = module.hub.private_dns_zone_ids
  deploy_example_private_endpoint = each.value.deploy_example_private_endpoint
  log_analytics_workspace_id      = module.management.log_analytics_workspace_id
  flow_log_settings               = module.management.flow_log_settings
}
