terraform {
  required_version = ">= 1.8.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.9.0" # exact pin in deployable roots; modules accept >= 4.80, < 5
    }
  }

  # Partial configuration: values come from backend.hcl at init time
  # (terraform init -backend-config=backend.hcl), so one codebase serves many states.
  backend "azurerm" {}
}
