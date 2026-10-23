resource "azurerm_consumption_budget_subscription" "this" {
  name            = "budget-${var.name_prefix}-monthly"
  subscription_id = local.subscription_scope
  amount          = var.budget.amount
  time_grain      = "Monthly"

  time_period {
    # Budgets must start on the first day of a month. The value is only
    # meaningful on creation, hence ignore_changes below.
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  notification {
    enabled        = true
    operator       = "GreaterThanOrEqualTo"
    threshold      = 80
    threshold_type = "Actual"
    contact_emails = var.budget.contact_emails
    contact_roles  = var.budget.contact_roles
  }

  notification {
    enabled        = true
    operator       = "GreaterThanOrEqualTo"
    threshold      = 100
    threshold_type = "Actual"
    contact_emails = var.budget.contact_emails
    contact_roles  = var.budget.contact_roles
  }

  notification {
    enabled        = true
    operator       = "GreaterThanOrEqualTo"
    threshold      = 100
    threshold_type = "Forecasted"
    contact_emails = var.budget.contact_emails
    contact_roles  = var.budget.contact_roles
  }

  lifecycle {
    ignore_changes = [time_period]
  }
}
