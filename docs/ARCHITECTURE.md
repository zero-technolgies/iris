# Iris — Architecture

This document describes the concrete technical structure of the current Iris implementation. For forward-looking design, see [`VISION.md`](VISION.md). For the strategic argument, see [`THESIS.md`](THESIS.md).

## One-sentence summary
A pipeline that turns scattered engineering events into a unified timeline of who did what, what happened to it, and how it performed — then makes that timeline queryable in natural language.

## The five layers

### 1. Sources
- **GitHub** — authorship and code review (commits, PRs, reviews)
- **GitHub Actions** — CI pipeline events (build started/succeeded/failed)
- **Container Registry (GHCR)** — built artifacts (image push, digest, tags)
- **ArgoCD** — deployment lineage and runtime state (sync events, drift detection)
- **Grafana stack (Mimir/Loki)** — runtime behavior and incidents

### 2. Ingestion
Webhooks and event streams land here. Normalized into a common envelope (timestamp, contributor ID, tenant ID, event type, payload), validated, stored immutably. Capture without loss.

### 3. Correlation
Joins raw events into facts. Push + pipeline + image + ArgoCD sync → `Contributor X's commit Y is serving traffic in environment Z as of timestamp T`. The join key between code-world and runtime-world is the ArgoCD sync event.

### 4. Insights
Computed on top of correlation. Pre-computed at event time, refreshed on schedule.

### 5. Interface
v0: CLI. Later: dashboard, voice, Slack/Teams. All read from Insights only.

## Cross-cutting concerns

### Contributor identity
The unit of observation. Either a human GitHub account or an agent identity. Treated uniformly downstream.

### Audit
Every event, decision, query, answer, action, approval logged with contributor and tenant context.

### Tenant boundary
Every record carries `tenant_id`. Every query filters by it. v0 has one tenant; the discipline is preserved.

## Seam contracts

- **Sources → Ingestion**: webhooks and pollers landing into a common envelope
- **Ingestion → Correlation**: an event log Correlation reads from
- **Correlation → Insights**: a stable schema of joined facts
- **Insights → Interface**: a query API (REST or GraphQL)

Each seam is a contract. Any region can be rewritten without touching the others if the contracts hold.

## Tooling

### Languages
- **Go** — backend services
- **TypeScript/React** — dashboard (later)
- **Python** — only where ML ecosystem demands it (probably not v0)

### Storage
- **Postgres** — correlation store
- **Object storage** (later) — long-term event archive

### Orchestration
- **Kubernetes** (k3s for v0, AKS for v2)
- **ArgoCD** — GitOps and deployment source of truth

## v0 scope

- One or two sources (start with ArgoCD spine, add GitHub for authorship)
- Simple correlation (commit → deployment)
- One insight (current deployment state with commit refs)
- CLI interface
- Single tenant, multi-tenant-ready schema

## What's deliberately not in v0

- Voice interface
- Agent-as-contributor identity model
- Per-developer scorecards
- Multi-cluster, multi-tenant operations
- Static analysis or security scan integration
