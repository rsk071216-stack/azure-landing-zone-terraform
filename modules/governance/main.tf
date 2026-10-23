locals {
  subscription_scope = "/subscriptions/${var.subscription_id}"

  # Built-in definitions referenced by their stable GUIDs (identical in every tenant).
  builtin = {
    allowed_locations         = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
    allowed_locations_rg      = "/providers/Microsoft.Authorization/policyDefinitions/e765b5de-1225-4ba3-bd56-1ac6695af988"
    require_tag_on_rg         = "/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025"
    inherit_tag_from_rg       = "/providers/Microsoft.Authorization/policyDefinitions/ea3f2387-9b95-492a-a190-fcdc54f7b070"
    deny_nic_public_ip        = "/providers/Microsoft.Authorization/policyDefinitions/83a86a26-fd1f-447c-b59d-e51f44264114"
    storage_no_public_access  = "/providers/Microsoft.Authorization/policyDefinitions/b2982f36-99f2-4db5-8eff-283140c09693"
    audit_diagnostic_setting  = "/providers/Microsoft.Authorization/policyDefinitions/7f89b1eb-583c-429a-8828-af049802c1d9"
    tag_contributor_role_guid = "4a9ae827-6dc8-4573-8ac7-8239d42aa03f"
  }

  # Single-instance assignments: key => definition, parameters, message.
  assignments = {
    allowed-locations = {
      display_name = "Allowed locations for resources"
      definition   = local.builtin.allowed_locations
      parameters   = { listOfAllowedLocations = { value = var.allowed_locations } }
      message      = "Resources may only be deployed to: ${join(", ", var.allowed_locations)}."
    }
    allowed-locations-rg = {
      display_name = "Allowed locations for resource groups"
      definition   = local.builtin.allowed_locations_rg
      parameters   = { listOfAllowedLocations = { value = var.allowed_locations } }
      message      = "Resource groups may only be created in: ${join(", ", var.allowed_locations)}."
    }
    deny-nic-public-ip = {
      display_name = "Network interfaces should not have public IPs"
      definition   = local.builtin.deny_nic_public_ip
      parameters   = {}
      message      = "Workloads are reached through the hub firewall or Bastion, never a public IP on a NIC."
    }
    deny-storage-public = {
      display_name = "Storage accounts should disable public network access"
      definition   = local.builtin.storage_no_public_access
      parameters   = { effect = { value = var.storage_public_access_effect } }
      message      = "Storage must be reached through a private endpoint. Set public_network_access_enabled = false."
    }
    audit-diagnostics = {
      display_name = "Audit diagnostic setting for platform resource types"
      definition   = local.builtin.audit_diagnostic_setting
      parameters   = { listOfResourceTypes = { value = var.diagnostic_resource_types } }
      message      = "Platform resources must stream logs to the central Log Analytics workspace."
    }
    subnet-requires-nsg = {
      display_name = "Subnets must have a network security group"
      definition   = azurerm_policy_definition.subnet_requires_nsg.id
      parameters   = { effect = { value = var.subnet_nsg_effect } }
      message      = "Associate an NSG with every workload subnet."
    }
  }
}

# ---------------------------------------------------------------------------
# Custom policy definitions
# ---------------------------------------------------------------------------

resource "azurerm_policy_definition" "deny_privatelink_dns_zones" {
  name         = "${var.name_prefix}-deny-privatelink-dns-zones"
  display_name = "Deny privatelink Private DNS zones outside the connectivity hub"
  description  = "Private Link DNS zones are owned centrally. A duplicate zone in a spoke silently breaks name resolution for every other spoke."
  policy_type  = "Custom"
  mode         = "All"

  metadata = jsonencode({ category = "Network", version = "1.0.0" })

  parameters = jsonencode({
    effect = {
      type          = "String"
      defaultValue  = "Deny"
      allowedValues = ["Audit", "Deny", "Disabled"]
      metadata      = { displayName = "Effect" }
    }
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        { field = "type", equals = "Microsoft.Network/privateDnsZones" },
        { field = "name", like = "privatelink*" },
      ]
    }
    then = { effect = "[parameters('effect')]" }
  })
}

resource "azurerm_policy_definition" "subnet_requires_nsg" {
  name         = "${var.name_prefix}-subnet-requires-nsg"
  display_name = "Subnets must have a network security group"
  description  = "Every workload subnet must be associated with an NSG. Azure-managed platform subnets are excluded."
  policy_type  = "Custom"
  mode         = "All"

  metadata = jsonencode({ category = "Network", version = "1.0.0" })

  parameters = jsonencode({
    effect = {
      type          = "String"
      defaultValue  = "Audit"
      allowedValues = ["Audit", "Deny", "Disabled"]
      metadata      = { displayName = "Effect" }
    }
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        { field = "type", equals = "Microsoft.Network/virtualNetworks/subnets" },
        { field = "name", notIn = ["GatewaySubnet", "AzureFirewallSubnet", "AzureFirewallManagementSubnet", "AzureBastionSubnet", "RouteServerSubnet"] },
        { field = "Microsoft.Network/virtualNetworks/subnets/networkSecurityGroup.id", exists = "false" },
      ]
    }
    then = { effect = "[parameters('effect')]" }
  })
}

# ---------------------------------------------------------------------------
# Assignments
# ---------------------------------------------------------------------------

resource "azurerm_subscription_policy_assignment" "this" {
  for_each = local.assignments

  name                 = "${var.name_prefix}-${each.key}"
  display_name         = each.value.display_name
  subscription_id      = local.subscription_scope
  policy_definition_id = each.value.definition
  parameters           = length(each.value.parameters) > 0 ? jsonencode(each.value.parameters) : null
  enforce              = var.enforce

  non_compliance_message {
    content = each.value.message
  }
}

resource "azurerm_subscription_policy_assignment" "deny_privatelink_dns_zones" {
  name                 = "${var.name_prefix}-deny-privatelink-dns"
  display_name         = "Deny privatelink Private DNS zones outside the connectivity hub"
  subscription_id      = local.subscription_scope
  policy_definition_id = azurerm_policy_definition.deny_privatelink_dns_zones.id
  not_scopes           = [var.central_dns_resource_group_id]
  enforce              = var.enforce

  non_compliance_message {
    content = "Private Link DNS zones are managed centrally in the hub. Use a private_dns_zone_group that points at the hub zone instead."
  }
}

# One assignment per required tag: Deny on resource groups...
resource "azurerm_subscription_policy_assignment" "require_tag_on_rg" {
  for_each = toset(var.required_tags)

  name                 = "${var.name_prefix}-require-rg-tag-${each.key}"
  display_name         = "Require tag '${each.key}' on resource groups"
  subscription_id      = local.subscription_scope
  policy_definition_id = local.builtin.require_tag_on_rg
  parameters           = jsonencode({ tagName = { value = each.key } })
  enforce              = var.enforce

  non_compliance_message {
    content = "Resource groups must carry the '${each.key}' tag."
  }
}

# ...and Modify on resources, so teams never have to repeat tags by hand.
resource "azurerm_subscription_policy_assignment" "inherit_tag_from_rg" {
  for_each = toset(var.required_tags)

  name                 = "${var.name_prefix}-inherit-tag-${each.key}"
  display_name         = "Inherit tag '${each.key}' from the resource group if missing"
  subscription_id      = local.subscription_scope
  policy_definition_id = local.builtin.inherit_tag_from_rg
  parameters           = jsonencode({ tagName = { value = each.key } })
  location             = var.location
  enforce              = var.enforce

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "inherit_tag_remediation" {
  for_each = toset(var.required_tags)

  scope              = local.subscription_scope
  role_definition_id = "${local.subscription_scope}/providers/Microsoft.Authorization/roleDefinitions/${local.builtin.tag_contributor_role_guid}"
  principal_id       = azurerm_subscription_policy_assignment.inherit_tag_from_rg[each.key].identity[0].principal_id
  principal_type     = "ServicePrincipal"
  description        = "Lets the '${each.key}' tag-inheritance policy remediate resources."
}

resource "azurerm_resource_group_policy_exemption" "storage_public_access" {
  for_each = var.storage_public_access_exemptions

  name                 = "${var.name_prefix}-exempt-storage-public-${each.key}"
  display_name         = "Flow-log storage written by Network Watcher as a trusted service"
  resource_group_id    = each.value
  policy_assignment_id = azurerm_subscription_policy_assignment.this["deny-storage-public"].id
  exemption_category   = "Mitigated"
  description          = "Network rules default to Deny; only trusted Azure services can write. Reviewed in ADR-0005."
}
