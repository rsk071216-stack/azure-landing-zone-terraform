variable "names" {
  description = "Name map produced by the `naming` module for the management scope."
  type        = map(string)
}

variable "location" {
  description = "Azure region for management resources."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource in this module."
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "Interactive retention for the Log Analytics workspace (30-730 days)."
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "log_retention_days must be between 30 and 730."
  }
}

variable "log_daily_quota_gb" {
  description = "Daily ingestion cap in GB. Protects non-production budgets from runaway logging; use -1 for no cap."
  type        = number
  default     = -1
}

variable "enable_vnet_flow_logs" {
  description = "Create the storage account used by VNet flow logs (NSG flow logs are retired by Microsoft)."
  type        = bool
  default     = true
}

variable "network_watcher" {
  description = <<-EOT
    Network Watcher used for VNet flow logs. Azure auto-creates `NetworkWatcher_<region>` in `NetworkWatcherRG`
    unless the subscription opted out; set `create = true` to manage it here instead.
  EOT
  type = object({
    create              = optional(bool, false)
    name                = optional(string)
    resource_group_name = optional(string, "NetworkWatcherRG")
  })
  default = {}
}
