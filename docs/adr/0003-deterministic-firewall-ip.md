# ADR-0003: Compute the firewall private IP instead of reading it

- Status: Accepted
- Date: 2026-10-23

## Context

Every spoke route table needs the firewall private IP as next hop. Reading it from
`azurerm_firewall.ip_configuration[0].private_ip_address` makes every spoke wait for the firewall, which takes
10 to 20 minutes to deploy, and leaves the value unknown at plan time (so plans cannot show, and tests cannot
assert, the real next hop).

## Decision

Azure Firewall always takes the first usable address (`.4`) of `AzureFirewallSubnet`. The hub module computes
`cidrhost(AzureFirewallSubnet, 4)` and exports it as `firewall_private_ip`.

The hub subnet plan is deterministic as well: the first four `/26` blocks of the hub range are reserved for
`AzureFirewallSubnet`, `AzureFirewallManagementSubnet`, `AzureBastionSubnet` and `GatewaySubnet` (`/27`).

## Consequences

- Spokes deploy in parallel with the firewall; the next hop is known at plan time and covered by unit tests.
- If Microsoft ever changed the allocation rule, routes would point at the wrong address. Mitigation: after the
  first real deployment, compare
  `az network firewall show -g <rg> -n <name> --query "ipConfigurations[0].privateIPAddress"`
  with the `hub.firewall_private_ip` output (part of the deployment checklist in the README).
