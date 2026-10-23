# ADR-0006: Native terraform test with mock providers as the primary test layer

- Status: Accepted
- Date: 2026-10-23

## Context

Infrastructure tests usually need a real subscription (Terratest, kitchen-terraform): slow, costly, and
impossible to run on pull requests from forks. Most landing-zone defects, however, are logic errors:
overlapping CIDRs, a missing route, a wrong DNS zone reference, a public endpoint left on.

## Decision

- Use `terraform test` (`*.tftest.hcl`) with `mock_provider "azurerm"`. Terraform loads the real provider
  schema, so type errors and invalid arguments are still caught, but no API is called.
- Shared mock data (`tests/mocks/azurerm.tfmock.hcl`) gives mocked resources realistic ARM IDs, because azurerm
  validates ID formats even when mocked. `override_resource` handles the few resources whose name is encoded in
  the ID (`AzureFirewallSubnet`, `AzureBastionSubnet`).
- Tests assert architectural invariants, not implementation details: routing to the firewall, DNS zone
  ownership, no public access, naming, tags, and guardrail failures (`expect_failures`).
- Each provider-backed suite includes a `command = apply` run against mocks to exercise the full graph,
  outputs and provider-side validation.
- CI runs every suite on the oldest supported Terraform minor and on the pinned current version.

## Consequences

- Over 40 assertions run in a couple of minutes on every pull request with no credentials.
- Mocks cannot prove Azure behaviour (API quirks, quotas, RBAC propagation). A real `plan` against a
  subscription (deploy workflow) remains the integration layer; see "What CI proves" in the README.
