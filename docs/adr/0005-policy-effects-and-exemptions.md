# ADR-0005: Policy effects, enforcement and exemptions

- Status: Accepted
- Date: 2026-10-23

## Context

Deny policies are the strongest guardrail, but they can block the platform's own deployments or break a
brownfield subscription on the first apply.

## Decision

- Built-in policies are referenced by their stable definition GUIDs, not by display-name lookups.
- `subnet-requires-nsg` defaults to **Audit**. With `Deny`, Azure evaluates the `azurerm_subnet` creation before
  the separate NSG association exists and rejects it. Switch to `Deny` only once subnets are created with
  inline NSGs, or for subscriptions where teams create subnets by other means.
- Storage public network access is **Deny**. The flow-log storage account in the management resource group is
  covered by an explicit, documented `Mitigated` **policy exemption** (network rules default to Deny; only
  trusted Azure services write) rather than by weakening the assignment.
- The privatelink DNS zone deny policy excludes only the hub resource group (`not_scopes`).
- Required tags: `Deny` on resource groups plus `Modify` (inherit from resource group) on resources. The Modify
  assignments get a system-assigned identity holding only `Tag Contributor`, and the deploying identity can grant
  nothing else (see the ABAC condition in `scripts/setup-oidc.sh`).
- `governance.enforce = false` switches every assignment to `DoNotEnforce` for a report-only brownfield rollout.

## Consequences

Exemptions are code-reviewed resources with a category and a reason, visible in Azure Policy compliance views.
