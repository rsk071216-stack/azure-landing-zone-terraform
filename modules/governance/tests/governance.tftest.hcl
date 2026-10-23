# Policy-as-code unit tests: prove which guardrails exist and how they are
# scoped, without deploying a single policy.

mock_provider "azurerm" {
  source = "../../tests/mocks"
}

variables {
  subscription_id               = "00000000-0000-0000-0000-000000000000"
  name_prefix                   = "alz-prod"
  location                      = "westeurope"
  allowed_locations             = ["westeurope", "northeurope"]
  central_dns_resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-prod-weu-001"
  budget                        = { amount = 1000, contact_emails = ["finops@example.com"] }
}

run "baseline_guardrails_are_assigned" {
  command = plan

  assert {
    condition = toset(keys(azurerm_subscription_policy_assignment.this)) == toset([
      "allowed-locations", "allowed-locations-rg", "deny-nic-public-ip",
      "deny-storage-public", "audit-diagnostics", "subnet-requires-nsg",
    ])
    error_message = "The baseline policy set changed; update the README compliance mapping too."
  }

  assert {
    condition     = jsondecode(azurerm_subscription_policy_assignment.this["allowed-locations"].parameters).listOfAllowedLocations.value == ["westeurope", "northeurope"]
    error_message = "Allowed locations must be passed through unchanged."
  }

  assert {
    condition     = jsondecode(azurerm_subscription_policy_assignment.this["deny-storage-public"].parameters).effect.value == "Deny"
    error_message = "Storage public network access must be denied by default."
  }

  assert {
    condition     = alltrue([for a in azurerm_subscription_policy_assignment.this : a.enforce])
    error_message = "Assignments must be enforced by default."
  }
}

run "central_dns_zones_are_protected" {
  command = plan

  assert {
    condition     = azurerm_subscription_policy_assignment.deny_privatelink_dns_zones.not_scopes == tolist([var.central_dns_resource_group_id])
    error_message = "The privatelink zone deny policy must exclude only the hub DNS resource group."
  }

  assert {
    condition     = jsondecode(azurerm_policy_definition.deny_privatelink_dns_zones.policy_rule).if.allOf[1].like == "privatelink*"
    error_message = "The custom DNS policy must match privatelink zones."
  }
}

run "every_required_tag_is_enforced_and_inherited" {
  command = plan

  assert {
    condition     = toset(keys(azurerm_subscription_policy_assignment.require_tag_on_rg)) == toset(["environment", "owner", "cost_center"])
    error_message = "Each required tag needs a Deny assignment on resource groups."
  }

  assert {
    condition     = alltrue([for a in azurerm_subscription_policy_assignment.inherit_tag_from_rg : a.identity[0].type == "SystemAssigned"])
    error_message = "Modify assignments need a managed identity to remediate."
  }
}

run "budget_alerts_before_overspend" {
  command = plan

  assert {
    condition     = azurerm_consumption_budget_subscription.this.amount == 1000 && azurerm_consumption_budget_subscription.this.time_grain == "Monthly"
    error_message = "Budget must be monthly with the requested amount."
  }

  assert {
    condition     = length([for n in azurerm_consumption_budget_subscription.this.notification : n if n.threshold_type == "Forecasted"]) == 1
    error_message = "A forecast alert is required so teams are warned before the money is spent."
  }
}

run "audit_only_rollout" {
  command = plan

  variables {
    enforce = false
  }

  assert {
    condition     = alltrue([for a in azurerm_subscription_policy_assignment.this : a.enforce == false])
    error_message = "enforce = false must put every assignment in DoNotEnforce mode."
  }
}

run "rejects_subscription_resource_id" {
  command = plan

  variables {
    subscription_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
  }

  expect_failures = [var.subscription_id]
}
