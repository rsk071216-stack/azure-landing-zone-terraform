# ADR-0004: Security baseline scope and cost-driven defaults

- Status: Accepted
- Date: 2026-10-23

## Context

A landing zone must be secure by default, yet a reference build that costs thousands per month will never be
deployed for evaluation.

## Decision

In scope and on by default:

- All egress through Azure Firewall; `default_outbound_access_enabled = false` on every subnet; BGP route
  propagation disabled on spoke route tables.
- No public IPs on NICs (policy), storage reachable only through private endpoints (policy), central Private DNS.
- Entra ID only: Log Analytics local auth disabled, storage shared keys disabled, OIDC for CI, keyless state.
- Diagnostic settings to one workspace, VNet flow logs with traffic analytics.

Configurable, with a cheaper default in dev:

- Firewall **Basic** in dev (no DNS proxy, threat intelligence in alert mode), **Standard** zone-redundant in
  prod. Premium (IDPS, TLS inspection) is one variable away.
- Bastion off in dev, Standard in prod.

Out of scope for this version (documented, not hidden):

- Customer-managed keys (CMK) for storage and Log Analytics.
- Azure DDoS Network Protection (roughly USD 2,900 per month).
- Microsoft Defender for Cloud plans and Microsoft Sentinel.
- Management group hierarchy (policies are assigned at subscription scope).

## Consequences

Checkov reports the CMK findings; they are skipped inline with a pointer to this ADR, so every exception is
explicit and reviewable.
