# ADR-0002: Spoke vending through a single map

- Status: Accepted
- Date: 2026-10-23

## Context

Platform teams lose most of their time on repetitive onboarding: a new application team needs a network,
routing, DNS, firewall rules, logging and policy compliance before it can deploy anything. Copy-pasted
spoke code drifts, and every drift is a potential security gap.

## Decision

- A spoke is one entry in `local.spokes` (`environments/<env>/spokes.tf`). The landing-zone module calls the
  `spoke` module with `for_each`, so every spoke is produced by the same code path.
- The spoke module owns **both** peering directions (spoke-to-hub and hub-to-spoke) and its own Private DNS
  zone links. Adding or removing a spoke never edits hub code.
- Workload firewall egress (`egress_fqdns`) is declared in the same map entry and rendered into the hub
  firewall policy, scoped to the source CIDR of that spoke only.
- Address plans are validated at plan time: spokes may not overlap each other or the hub, and subnets must
  fit inside their spoke.

## Consequences

- Onboarding a team is a reviewed pull request of roughly 15 lines.
- `for_each` keys are spoke names, so renaming a key destroys and recreates the spoke. Treat keys as
  immutable (documented in the README).
- The hub-side peering is created by the spoke, so the deploying identity needs write access to the hub
  resource group. In a multi-subscription design this becomes a cross-subscription provider alias (roadmap).
