variable "subscription_id" {
  description = "Target subscription GUID. Supply via TF_VAR_subscription_id (CI) or a local *.auto.tfvars that is git-ignored."
  type        = string
}

variable "budget_contact_emails" {
  description = "Addresses that receive budget alerts."
  type        = list(string)
  default     = []
}
