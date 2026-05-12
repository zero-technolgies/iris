# Iris — Project Context

## What this is
Iris is an engineering intelligence platform that turns scattered events from GitHub, ArgoCD, container registries, and observability tools into a unified, queryable timeline of contributor activity and system behavior. Both humans and AI agents are treated as first-class contributors.

The first goal is to solve a personal flow problem (Caleb, sole user). The architecture is built to generalize into a broader platform once it proves itself.

## Current phase
v0 — building the smallest version that proves the data model. One source (ArgoCD or GitHub), simple correlation, CLI interface. No voice, no agent-as-contributor identity model yet.

## Foundation status
- iris-host (Dell Precision 7820, Ubuntu Server 26.04 LTS) — built, headless, hardened
- k3s cluster — installed, healthy
- cert-manager + Let's Encrypt via Route 53 DNS-01 — installed and working
- ArgoCD — installed, accessible at https://argocd.iris.calebache.com (LAN-only)

## Core architecture (5 layers)
1. **Sources** — GitHub, GitHub Actions, ArgoCD, Container Registry, Grafana stack
2. **Ingestion** — webhook receivers, normalize events into a common envelope
3. **Correlation** — join events into a unified timeline (commit → deployment → incident)
4. **Insights** — pre-computed metrics and queryable views
5. **Interface** — CLI for v0, voice and dashboard later

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for full detail. See [`VISION.md`](VISION.md) for forward-looking design. See [`THESIS.md`](THESIS.md) for the strategic argument.

## Key decisions live in `/docs/adr/`
Each architectural decision gets its own ADR file. Read these before proposing changes that affect them.

## Conventions
See [`CONVENTIONS.md`](CONVENTIONS.md) for code style, commit format, branch naming.

## Contributors
- **Caleb** — owner, integrator, final reviewer, merger
- **Claude (chat)** — strategy, architecture, ClickUp planning, doc authoring
- **Claude Code** — implementation, opens PRs
- **Codex** — PR review against acceptance criteria

See [`AI_COLLABORATION.md`](AI_COLLABORATION.md) for the working model.

## Tracking
Tasks live in ClickUp under the Iris space. PRs link to ClickUp tasks via the PR template.

## Hosting
- Code: GitHub (private repo, github.com/Calebache/iris)
- Cluster (v0): single-node k3s on iris-host
- Container registry: GitHub Container Registry (GHCR)
- Observability (v0): TBD — Grafana Cloud free tier candidate
