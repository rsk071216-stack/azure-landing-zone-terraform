output "hub" {
  description = "Hub connectivity details."
  value       = module.landing_zone.hub
}

output "spokes" {
  description = "Per-spoke network details."
  value       = module.landing_zone.spokes
}

output "private_dns_zone_ids" {
  description = "Central Private DNS zone IDs."
  value       = module.landing_zone.private_dns_zone_ids
}

output "log_analytics_workspace_id" {
  description = "Central Log Analytics workspace."
  value       = module.landing_zone.log_analytics_workspace_id
}
