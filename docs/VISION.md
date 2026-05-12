---
title: Iris — Vision (v0 SDLC implementation)
doc_type: vision
status: current + forward-looking
audience: new technical contributors (human or AI)
version: 1.0.0
---

# Iris — Vision

This document describes the current implementation of Iris — the v0 SDLC instance. For the broader strategic argument, see [`THESIS.md`](THESIS.md). For day-to-day orientation, see [`CONTEXT.md`](CONTEXT.md).

## 1. Summary

In one sentence: **Iris is an engineering intelligence and action platform that watches an entire software delivery lifecycle, understands who did what and how it performed, and — with explicit human approval — acts on that understanding.**

The plain-language framing: **Iris does my job without me touching a key, but I give it final approval and verify the result.**

This is one instance of a larger thesis. See [`THESIS.md`](THESIS.md).

## 2. Core principles

These principles are load-bearing.

**Agents are first-class contributors.** A human committing code and an AI agent committing code occupy the same conceptual slot. The data model never special-cases humans.

**Human-in-the-loop is non-negotiable.** No action that modifies a system the human cares about executes without explicit human approval.

**Events flow forward; queries pull backward.** Sources emit events; ingestion captures them; correlation joins them; insights are pre-computed views; interfaces query the views. Nothing is computed at query time from raw sources.

**Clean seams between layers.** Each layer talks to neighbors through stable contracts. Any layer can be rewritten without touching the others.

**Build for one user, design for many.** v0 is single-user. The data model is multi-tenant from day zero.

**Audit everything.** Every event, correlation, query, answer, action, and approval is logged with attribution.

## 3. The five-layer architecture

```
┌────────────────────────────────────────────────────────┐
│  Layer 5 — Interface                                   │
│  (CLI, voice agent, dashboard, Slack/Teams bots)       │
└────────────────────────────────────────────────────────┘
                       ↓ queries
┌────────────────────────────────────────────────────────┐
│  Layer 4 — Insights                                    │
│  (pre-computed views: DORA metrics, contributor        │
│   quality, service health, hotspot analysis)           │
└────────────────────────────────────────────────────────┘
                       ↓ reads
┌────────────────────────────────────────────────────────┐
│  Layer 3 — Correlation                                 │
│  (joins events into a unified timeline)                │
└────────────────────────────────────────────────────────┘
                       ↑ reads
┌────────────────────────────────────────────────────────┐
│  Layer 2 — Ingestion                                   │
│  (webhooks normalized into a common envelope, stored   │
│   immutably)                                           │
└────────────────────────────────────────────────────────┘
                       ↑ receives from
┌────────────────────────────────────────────────────────┐
│  Layer 1 — Sources                                     │
│  (GitHub, GitHub Actions, ArgoCD, container registry,  │
│   observability stack)                                 │
└────────────────────────────────────────────────────────┘
```

### Layer 1 — Sources
Systems of record. GitHub (authorship/review), GitHub Actions (CI), Container Registry (artifacts), ArgoCD (deployment lineage), Grafana stack (runtime/incidents). Each owns a distinct stage. No overlap.

### Layer 2 — Ingestion
Webhooks land here, normalized to a common envelope (timestamp, contributor ID, tenant ID, event type, payload), validated, stored immutably. Capture without loss. No interpretation.

### Layer 3 — Correlation
Raw events become meaning. Push + pipeline run + image push + ArgoCD sync joined into: *"Contributor X's commit Y is serving traffic in environment Z as of timestamp T."* The join key between code-world and runtime-world is the ArgoCD sync event.

### Layer 4 — Insights
Computed on top of correlation. DORA metrics, contributor quality, hotspot analysis, agent telemetry. Pre-computed at event time. Cheap to query.

### Layer 5 — Interface
v0 is CLI. Later: dashboard, voice, Slack/Teams. All read from Insights only.

## 4. Cross-cutting concerns

**Contributor identity.** Unit of observation. Either a human GitHub account or an agent identity (model + version + system prompt hash + tool config). Treated uniformly. Minimum fields: `id`, `type` (`human`/`coding_agent`/`voice_agent`/`review_agent`/`unknown`), `tenant_id`, `display_name`, `external_refs`, `created_at`, `last_seen_at`.

**Audit.** Every event, decision, query, answer, action, approval logged with contributor and tenant context. Immutable. Queryable.

**Tenant boundary.** Every record carries `tenant_id`. Every query filters by `tenant_id`. v0 has one tenant. Discipline preserved.

## 5. The action layer (designed, deferred to post-v0)

The action layer turns Iris from observer to participant. Designed as part of the overall architecture but deferred to a later phase.

**What it does**: takes a directive (voice or other), interprets it against Iris's understanding, dispatches work to a capable agent, surfaces the result for human approval.

**Minimum viable flow**:
1. Human speaks a directive
2. Action layer parses intent
3. Pulls context (ticket content, acceptance criteria, relevant code state) via MCP servers and Iris's own insights
4. **Approval gate**: synthesizes a brief, asks human to confirm
5. On approval: emits dispatch to coding agent
6. Coding agent (Claude Code, Codex) creates branch, implements, opens PR with criteria in body
7. Review agent reviews against criteria
8. Action layer notifies human PR is ready
9. Human reviews and merges

**Architectural placement**: orthogonal to the five layers. Consumes Layer 4, produces events back into Layer 1. Makes Iris self-observing.

**Components** (all replaceable):
- Voice front-end (Retell, Vapi, ElevenLabs, or custom)
- Orchestrator (custom Go)
- Context provider (built on MCP servers)
- Agent dispatch protocol (TBD)
- Approval gate
- Self-observation loop

**Pre-conditions for building**:
1. v0 complete
2. Contributor identity model validated against real data
3. At least one meaningful insight worth acting on
4. Caleb has used observation capabilities long enough to know what's worth automating

## 6. Use case 1 — Observation

**Scenario**: Caleb wants to know if Codex (review agent) is missing bugs that production catches.

**Trigger**: *"Show me PRs in the last 30 days where Codex approved but a bug was filed against the deployed change within seven days."*

**Flow**:
1. Interface parses the request
2. Query hits Layer 4 (pre-computed `pr_outcomes` table joining PR ID, reviewer ID, decision, merge timestamp, attributed incidents within configurable window)
3. Filters: reviewer = Codex; decision = approved; incidents > 0; merge in last 30 days
4. Returns matching PR records with attribution

**Components touched**: Interface → Insights only. Sub-second latency.

**Proves**: Observation works. Iris answers what no individual tool can answer.

## 7. Use case 2 — Action (with approval)

**Scenario**: Ticket triaged, ready for implementation. Caleb wants Iris to dispatch without him copying criteria, creating branches, or opening PRs.

**Trigger**: *"Iris, take ticket CU-86xxxxx, dispatch to Claude Code, let me know when PR is ready."*

**Flow**:
1. Voice transcribes → Orchestrator
2. Orchestrator parses: `action=dispatch_implementation; target=CU-86xxxxx; agent=claude_code`
3. Context provider fetches ticket (ClickUp MCP), repo state (GitHub MCP), file context (Iris Insights)
4. **Approval gate**: *"Ticket fetched. 4 criteria. Target file: services/ingestion/handler.go. Two recent incidents on this file. Dispatch?"*
5. Caleb approves (audited event)
6. Orchestrator emits dispatch brief
7. Claude Code creates branch, implements, opens PR with criteria pasted in body
8. PR event flows back into Iris (Sources → Ingestion → Correlation → Insights), attributed to `coding_agent:claude_code`
9. Codex reviews against criteria
10. On approval, Orchestrator notifies Caleb
11. Caleb reviews and merges (final approval gate)

**Proves**: Iris can do work, not just describe it.

## 8. Status of components

| Component | Status |
|---|---|
| iris-host (Linux server) | Built |
| k3s cluster | Built |
| cert-manager + Route 53 DNS-01 | Built |
| ArgoCD | Built (UI at argocd.iris.calebache.com) |
| GitHub source | Designed (Epic 2) |
| GitHub Actions source | Designed (Epic 2) |
| Container Registry (GHCR) | Designed (Epic 2) |
| ArgoCD as source | Designed (Epic 4) |
| Grafana stack | Designed (later) |
| Layer 2 — Ingestion | Designed (Epic 3) |
| Layer 3 — Correlation | Designed (Epic 5) |
| Layer 4 — Insights | Designed (Epic 5/6) |
| Layer 5 — Interface (CLI) | Designed (Epic 6) |
| Action Layer | Designed, deferred to post-v0 |
| Contributor identity model | In progress (Epic 3) |
| Audit logging | Cross-cutting, incremental |
| Tenant boundary | Schema discipline from day one |

## 9. Migration path

| Phase | What runs | Where | Cost |
|---|---|---|---|
| v0 | k3s, Postgres, ingestion, correlation, CLI | iris-host | ~$15–30/mo |
| v1 | Same + more sources, insights, dashboard | iris-host | ~$30–50/mo |
| v2 | First serious demo or paying customer | AKS, ACR, self-hosted observability | scales with usage |
| v3 | Action layer enabled | Same + voice infrastructure | adds voice platform costs |

Architecture does not change between phases. Only infrastructure underneath does.

## 10. Open questions

1. Which voice platform (Retell, Vapi, ElevenLabs, custom)?
2. Which agent dispatch protocol (MCP, watched directory, custom, emerging standard)?
3. How to handle out-of-context approvals (phone notification, signed token, TTL)?
4. Should agents communicate directly, or only through artifacts?
5. Public exposure vs Tailscale-only — does Iris ever need to be publicly reachable?

## 11. What this document is not

- Not implementation details (those live in `ARCHITECTURE.md`, ADRs, code)
- Not tool-specific tutorials
- Not day-to-day work tracking (ClickUp owns that)
- Not personnel policies (`AI_COLLABORATION.md`)

Update when vision shifts, not when implementation details change.
