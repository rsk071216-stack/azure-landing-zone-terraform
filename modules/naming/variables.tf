variable "workload" {
  description = "Short workload or platform component name, e.g. `hub`, `mgmt`, `payments`. Lowercase letters and digits, 2-12 characters."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,11}$", var.workload))
    error_message = "workload must be 2-12 lowercase alphanumeric characters and start with a letter."
  }
}

variable "environment" {
  description = "Environment short name. One of: sbx, dev, test, uat, prod."
  type        = string

  validation {
    condition     = contains(["sbx", "dev", "test", "uat", "prod"], var.environment)
    error_message = "environment must be one of: sbx, dev, test, uat, prod."
  }
}

variable "location" {
  description = "Azure region name, e.g. `westeurope`. Mapped to a short code for resource names."
  type        = string
}

variable "instance" {
  description = "Three-digit instance number, used to run more than one copy of the same workload in a region."
  type        = string
  default     = "001"

  validation {
    condition     = can(regex("^[0-9]{3}$", var.instance))
    error_message = "instance must be exactly three digits, e.g. 001."
  }
}

variable "unique_seed" {
  description = "Optional seed (e.g. the subscription ID) hashed into a short suffix for globally unique names such as storage accounts. Defaults to the name suffix."
  type        = string
  default     = null
}
