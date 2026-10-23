output "policy_assignment_ids" {
  description = "Map of assignment name to policy assignment ID."
  value = merge(
    { for key, a in azurerm_subscription_policy_assignment.this : a.name => a.id },
    { for key, a in azurerm_subscription_policy_assignment.require_tag_on_rg : a.name => a.id },
    { for key, a in azurerm_subscription_policy_assignment.inherit_tag_from_rg : a.name => a.id },
    { (azurerm_subscription_policy_assignment.deny_privatelink_dns_zones.name) = azurerm_subscription_policy_assignment.deny_privatelink_dns_zones.id },
  )
}

output "custom_policy_definition_ids" {
  description = "IDs of the custom policy definitions created by this module."
  value = {
    deny_privatelink_dns_zones = azurerm_policy_definition.deny_privatelink_dns_zones.id
    subnet_requires_nsg        = azurerm_policy_definition.subnet_requires_nsg.id
  }
}

output "budget_id" {
  description = "Subscription budget ID."
  value       = azurerm_consumption_budget_subscription.this.id
}
