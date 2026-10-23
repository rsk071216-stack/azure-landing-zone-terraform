# ADR-0007: Central Private Link DNS in the hub

- Status: Accepted
- Date: 2026-10-23

## Context

Private endpoints only work if their FQDN resolves to the private IP from every network that uses them. When
a team creates its own `privatelink.blob.core.windows.net` zone in a spoke, resolution for that service breaks
for every VNet linked to the other copy: a classic, hard-to-diagnose outage.

## Decision

- All `privatelink.*` zones live once, in the hub resource group, and are linked to the hub and to every spoke.
- Private endpoints register through `private_dns_zone_group` pointing at the hub zone.
- A custom policy denies `privatelink*` zones anywhere except the hub resource group.
- With Firewall Standard or Premium, DNS proxy is enabled and spokes use the firewall IP as DNS server
  (required for FQDN-based network rules). On Basic, which has no DNS proxy, spokes use Azure-provided DNS
  through their zone links.

## Consequences

Hybrid resolution from on-premises needs an Azure DNS Private Resolver inbound endpoint in the hub (roadmap
item; the hub address plan keeps room for it).
