# Unit tests for the naming convention. No provider is involved, so these
# run in milliseconds and need no credentials.

variables {
  workload    = "payments"
  environment = "prod"
  location    = "westeurope"
}

run "follows_caf_pattern" {
  command = plan

  assert {
    condition     = output.suffix == "payments-prod-weu-001"
    error_message = "Suffix must be <workload>-<environment>-<region>-<instance>."
  }

  assert {
    condition     = output.names.virtual_network == "vnet-payments-prod-weu-001"
    error_message = "VNet name must use the CAF 'vnet' abbreviation as prefix."
  }

  assert {
    condition = alltrue([
      for key, name in output.names : can(regex("^[a-z]+-[a-z0-9]+-(sbx|dev|test|uat|prod)-[a-z0-9]+-[0-9]{3}$", name))
      if !contains(["storage_account", "key_vault"], key)
    ])
    error_message = "Every hyphenated name must match <abbr>-<workload>-<env>-<region>-<nnn>."
  }
}

run "storage_account_name_is_valid" {
  command = plan

  variables {
    workload    = "verylongname"
    unique_seed = "00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = can(regex("^[a-z0-9]{3,24}$", output.names.storage_account))
    error_message = "Storage account names must be 3-24 lowercase alphanumeric characters."
  }

  assert {
    condition     = length(output.names.key_vault) <= 24
    error_message = "Key Vault names must not exceed 24 characters."
  }
}

run "unknown_region_falls_back_to_full_name" {
  command = plan

  variables {
    location = "brazilsouth"
  }

  assert {
    condition     = output.region_code == "brazilsouth"
    error_message = "Unmapped regions must fall back to the region name rather than fail."
  }
}

run "rejects_invalid_environment" {
  command = plan

  variables {
    environment = "production"
  }

  expect_failures = [var.environment]
}

run "rejects_uppercase_workload" {
  command = plan

  variables {
    workload = "Payments"
  }

  expect_failures = [var.workload]
}
