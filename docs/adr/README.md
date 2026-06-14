# Architecture Decision Records

This directory contains the architectural decision records for Iris.

## When to write an ADR
- The decision affects more than one service or layer
- The decision constrains future choices
- The decision was non-obvious and required deliberation
- The decision was contested or had multiple reasonable answers

## How to write one
1. Copy `0000-template.md` to a new file with the next sequential number
2. Pick a short, descriptive title
3. Fill in Context, Decision, Consequences, Alternatives
4. Set status to `Proposed`, open a PR
5. After merge, status becomes `Accepted`

## When a decision is reversed
Don't delete the old ADR. Create a new one that supersedes it, and update the old one's status to `Superseded by ADR-NNNN`.

## Index
- [ADR-0001: Record architecture decisions](0001-record-architecture-decisions.md)
- [ADR-0002: App-of-Apps pattern with auto-sync and no-prune](0002-app-of-apps-gitops-pattern.md)
- [ADR-0003: Container registry strategy](0003-container-registry-strategy.md)
- [ADR-0004: Postgres via CloudNativePG](0004-postgres-cloudnativepg.md)
- [ADR-0005: Ingestion migrations and initial schema](0005-ingestion-migrations-and-initial-schema.md)
- [ADR-0006: ArgoCD event delivery via webhooks and MCP](0006-argocd-event-delivery.md)
- [ADR-0007: Cloudflare Tunnel ingress for public webhooks](0007-cloudflare-tunnel-ingress.md)
