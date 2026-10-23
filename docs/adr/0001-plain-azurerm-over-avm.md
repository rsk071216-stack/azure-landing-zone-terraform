# ADR-0001: Plain azurerm resources instead of Azure Verified Modules

- Status: Accepted
- Date: 2026-10-23

## Context

Azure Verified Modules (AVM) are Microsoft's recommended building blocks and a sensible default for new
greenfield work. While designing this repository the AVM virtual network module
(`Azure/avm-res-network-virtualnetwork/azurerm`, latest `0.22.3`, published 2026-10-13) was evaluated.
Its registry metadata declares dependencies on `Azure/azapi ~> 2.12`, `azure/modtm ~> 0.3` (telemetry),
`hashicorp/random` and `hashicorp/http` in addition to `azurerm`.

The core differentiator of this repository is a fast, credential-free unit test suite (`terraform test`
with `mock_provider`), see [ADR-0006](0006-native-tests-with-mock-providers.md).

## Decision

Use plain `azurerm` 4.x resources inside small local modules. Do not consume AVM in this version.

## Consequences

- One provider to mock. Tests assert directly on resource attributes (`azurerm_route.default.next_hop_in_ip_address`)
  instead of on whatever a third-party module chooses to expose.
- No telemetry provider or outbound HTTP calls during plan.
- No pre-1.0 AVM version churn (the module had several releases in the weeks before this decision).
- We own more code (roughly 700 lines of HCL). Acceptable for a landing zone, which changes rarely and must be
  fully understood by the team that operates it.
- Revisit when the AVM resource modules reach 1.0 and `azapi` can be mocked with realistic IDs (roadmap item).
  The module boundaries here (hub, spoke, governance) map one-to-one to AVM pattern modules, so a migration
  would stay internal to each module.
