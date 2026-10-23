output "suffix" {
  description = "Name suffix shared by every resource in this scope, e.g. `hub-prod-weu-001`."
  value       = local.suffix
}

output "region_code" {
  description = "Short region code used in names, e.g. `weu`."
  value       = local.region_code
}

output "abbreviations" {
  description = "CAF abbreviation map, for callers that compose child resource names (e.g. one NSG per subnet)."
  value       = local.abbreviations
}

output "names" {
  description = "Ready-to-use resource names keyed by resource type, e.g. `names.virtual_network`."
  value       = local.names
}
