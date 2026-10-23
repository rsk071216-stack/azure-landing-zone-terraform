locals {
  # Microsoft Cloud Adoption Framework (CAF) resource abbreviations.
  # https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations
  abbreviations = {
    action_group           = "ag"
    bastion                = "bas"
    budget                 = "budget"
    firewall               = "afw"
    firewall_policy        = "afwp"
    key_vault              = "kv"
    log_analytics          = "log"
    network_security_group = "nsg"
    network_watcher        = "nw"
    private_endpoint       = "pep"
    public_ip              = "pip"
    resource_group         = "rg"
    route_table            = "rt"
    storage_account        = "st"
    subnet                 = "snet"
    virtual_network        = "vnet"
    vnet_flow_log          = "fl"
    vnet_peering           = "peer"
  }

  # Short region codes keep names inside Azure length limits.
  region_codes = {
    australiaeast      = "aue"
    canadacentral      = "cac"
    centralindia       = "inc"
    centralus          = "cus"
    eastus             = "eus"
    eastus2            = "eus2"
    francecentral      = "frc"
    germanywestcentral = "gwc"
    northeurope        = "neu"
    qatarcentral       = "qac"
    southeastasia      = "sea"
    swedencentral      = "sdc"
    uaenorth           = "uan"
    uksouth            = "uks"
    ukwest             = "ukw"
    westeurope         = "weu"
    westus2            = "wus2"
    westus3            = "wus3"
  }

  location    = lower(replace(var.location, " ", ""))
  region_code = lookup(local.region_codes, local.location, local.location)

  # <workload>-<environment>-<region>-<instance>, e.g. hub-prod-weu-001
  suffix = join("-", [var.workload, var.environment, local.region_code, var.instance])

  # Six hex characters derived from a stable seed: deterministic across plans,
  # but different per subscription when the subscription ID is used as seed.
  unique = substr(sha256(coalesce(var.unique_seed, local.suffix)), 0, 6)

  # Storage accounts: 3-24 chars, lowercase letters and digits only, globally unique.
  storage_account = substr(
    replace("${local.abbreviations.storage_account}${var.workload}${var.environment}${local.region_code}${local.unique}", "/[^a-z0-9]/", ""),
    0, 24
  )

  names = merge(
    { for key, abbr in local.abbreviations : key => "${abbr}-${local.suffix}" },
    {
      storage_account = local.storage_account
      key_vault       = trimsuffix(substr("kv-${var.workload}-${var.environment}-${local.region_code}-${local.unique}", 0, 24), "-")
    }
  )
}
