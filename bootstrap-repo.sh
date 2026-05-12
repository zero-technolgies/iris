#!/usr/bin/env bash
#
# Iris repo bootstrap
# ===================
#
# Creates the foundational directory structure and writes the initial set of
# documentation, PR templates, and scaffolding files for the Iris project.
#
# USAGE
#   1. Clone the repo:    git clone https://github.com/Calebache/iris.git
#   2. cd into it:         cd iris
#   3. Run this script:    bash bootstrap-repo.sh
#   4. Review changes:     git status && git diff --stat
#   5. Commit:             git add . && git commit -m "chore: bootstrap repo structure and foundation docs"
#   6. Push:               git push origin main
#
# This script is idempotent for directory creation but will overwrite existing
# files. Do not run it after the repo has work in it.

set -euo pipefail

# Sanity check: we must be in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "ERROR: Not inside a git repository. Clone the repo first, then run this script from inside it."
  exit 1
fi

# Sanity check: refuse to run if the repo already has commits with code
if [ -d "services" ] || [ -d "deploy" ]; then
  echo "ERROR: Repo appears to already have structure. Aborting to avoid overwriting work."
  exit 1
fi

echo "==> Creating directory structure"
mkdir -p docs/adr docs/setup docs/runbooks
mkdir -p services
mkdir -p deploy
mkdir -p scripts
mkdir -p .github

# Keep empty directories tracked by git
touch services/.keep
touch deploy/.keep
touch scripts/.keep

echo "==> Writing .gitignore"
cat > .gitignore <<'EOF'
# OS
.DS_Store
Thumbs.db

# Editors
.vscode/
.idea/
*.swp
*.swo
*~

# Environment
.env
.env.local
*.env

# Go
*.exe
*.exe~
*.dll
*.so
*.dylib
*.test
*.out
vendor/
go.work
go.work.sum

# Node (in case any tooling needs it)
node_modules/
dist/
build/

# Logs
*.log

# Secrets
*.pem
*.key
*.crt
secrets/
EOF

echo "==> Writing README.md"
cat > README.md <<'EOF'
# Iris

Engineering intelligence and action platform.

## Status

v0 — proof of concept. See [`docs/CONTEXT.md`](docs/CONTEXT.md) for current state.

## Documentation

- [`docs/THESIS.md`](docs/THESIS.md) — strategic argument for the platform
- [`docs/VISION.md`](docs/VISION.md) — current implementation vision
- [`docs/CONTEXT.md`](docs/CONTEXT.md) — project orientation
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — technical structure
- [`docs/CONVENTIONS.md`](docs/CONVENTIONS.md) — code, commit, and review discipline
- [`docs/AI_COLLABORATION.md`](docs/AI_COLLABORATION.md) — multi-AI working model
- [`docs/REVIEW_GUIDE.md`](docs/REVIEW_GUIDE.md) — instructions for the PR reviewer
- [`docs/adr/`](docs/adr/) — architecture decision records

## Layout

```
/docs/          documentation
/services/      Go services, one folder per service
/deploy/        Kubernetes manifests, Helm charts, ArgoCD Applications
/scripts/       bootstrap and utility scripts
/.github/       workflows, PR templates, issue templates
```
EOF

echo "==> Writing docs/CONTEXT.md"
cat > docs/CONTEXT.md <<'EOF'
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
EOF

echo "==> Writing docs/THESIS.md"
cat > docs/THESIS.md <<'EOF'
---
title: Iris — Thesis
doc_type: thesis
status: foundational
audience: founders, investors, future contributors, future self
version: 1.0.0
---

# Iris — Thesis

## Preface

This document is the strategic argument for Iris. It exists separately from `VISION.md` (which describes a specific implementation in progress) because the thesis precedes any single implementation. If the v0 build succeeds, this thesis is what the next, properly-engineered project will be built against. If v0 fails or reveals the thesis to be wrong, this document is what gets revised, not the implementation.

Read this when you need to remember *why* — not *how*, not *what*, but why Iris should exist at all.

## 1. The thesis in one sentence

**Every domain that produces structured human activity across multiple systems has the same unsolved problem: nobody can see, understand, or act on what's actually happening across the whole. Iris is a domain-agnostic platform that solves that problem once, then adapts to each domain.**

## 2. The problem Iris exists to solve

Wherever people work in a domain — software engineering, healthcare, education, sales, personal life — their activity is scattered across many systems. Each system holds a partial view. No system holds the whole.

A software organization runs GitHub, Jira, ArgoCD, Datadog, Slack, AWS billing, on-call rotations. Each tool answers its own questions. None of them answer "which engineer's work is producing the most downstream incidents in production?" — because that question requires joining six systems together at the right grain, attributing to the right contributor, and surfacing the answer at the right moment.

A hospital runs an EHR, a lab system, scheduling, pharmacy, imaging, billing. Each tool answers its own questions. None of them answer "which patients in my panel today have lab results outside their normal range that the referring physician hasn't been notified about?" — same shape of problem.

An education system runs an LMS, a gradebook, attendance, parent communication, assessment tools. None of them answer "which students are showing the pattern that historically precedes dropout, and which interventions have worked for similar students?" — same shape of problem.

A person runs a calendar, an email inbox, social media accounts, fitness trackers, a banking app, a health portal. None of them answer "given how I've been sleeping, eating, and working this month, what's the one change most likely to move my baseline?" — same shape of problem.

The pattern is universal. The implementation is everywhere absent.

## 3. Why this problem is unsolved

Three categories of attempt exist, and all of them are insufficient.

**Vertical point solutions.** Tools that solve one corner of the problem within one domain. For SDLC: LinearB, Jellyfish, DX, Faros AI, Sleuth. For healthcare: clinical decision support tools, patient flow systems. They work, often well, within their narrow scope. But each is hardcoded to a domain and a question class. Each requires its own integrations, its own data model, its own UI. The market is fragmented because every vendor has rebuilt the same plumbing for a different vertical.

**Generic BI and analytics platforms.** Tableau, Looker, Snowflake, Databricks. These give you the raw infrastructure to answer cross-system questions, but only if you do all the work yourself: model the data, write the joins, build the dashboards, maintain the pipelines. They are powerful but inert. They do not understand what they are showing. They cannot act. And the people who can actually use them are a small specialist class within any organization.

**General-purpose AI assistants.** ChatGPT, Claude, Gemini. They can reason about anything but know nothing specific about your systems. They cannot see your data unless you paste it in. They cannot act on your behalf without bespoke integration. They are conversation surfaces with no anchor in the operational reality of the domain.

**The gap**: there is no platform that (a) understands a domain deeply enough to answer real questions, (b) is generic enough to adapt to any domain, (c) acts as well as it answers, and (d) maintains the audit and approval discipline required to be trusted with real consequences.

That gap is what Iris is built to fill.

## 4. The Iris bet

The thesis is that **a single, well-designed core can serve any domain by changing its adapters, not its engine.**

This bet rests on a structural observation: the problem of "see, understand, act across many systems" has the same shape in every domain. The systems differ. The vocabulary differs. The compliance requirements differ. But the underlying pattern is invariant:

1. Events flow continuously from many sources
2. Events must be normalized into a common shape
3. Events must be correlated into meaningful units of activity
4. Correlations must be surfaced as queryable insights
5. Insights must be expressible in the language the domain speaks
6. Actions taken on those insights must require explicit human approval
7. Everything must be audited

If the engine that does items 1, 2, 3, 4, 6, and 7 is built once, generically, then adapting Iris to a new domain is item 5 plus the source adapters. That is a feasible scope. Building a new vertical product per domain is not.

**This is the bet**: that the engine can be generic enough to be reusable, while being specific enough to be useful.

## 5. What makes Iris different

If the thesis is right, Iris differs from every existing approach along these axes:

**Domain-agnostic at the core, domain-specific at the edges.** The five-layer architecture and the cross-cutting concerns are generic. The source adapters, domain vocabulary, and action handlers are domain-specific. The seam between the two is the platform's most important boundary.

**Action as a first-class capability.** Iris does not stop at answering questions. It can be directed to take action with the constraint that every action requires explicit human approval. Most existing platforms in this space are observation-only.

**Agents and humans treated uniformly.** A doctor and an AI scheduling agent are both contributors. A developer and an AI coding agent are both contributors. This is not a minor data modeling choice. It is the architectural decision that makes the action layer possible at all.

**Audit is not an afterthought.** Every event, decision, query, answer, action, and approval is logged with full attribution. Required for regulated domains, and turns out to be valuable everywhere.

**Human approval is non-negotiable.** No action that modifies a system the human cares about executes without explicit human approval. This is a constraint, not a feature.

## 6. Why now

Three forces converge to make this thesis viable in 2026:

**LLMs can reason across heterogeneous data.** Five years ago, building a system that could answer arbitrary natural-language questions over a normalized event stream would have required building a domain-specific NLU stack per domain. Now, a competent LLM does that automatically, given the right context.

**Standard agent protocols are emerging.** MCP and adjacent efforts mean that connecting Iris to a new system is increasingly a configuration task rather than an integration project.

**Trust in AI-driven action is maturing.** The pattern of "AI proposes, human approves" is now well-understood and well-tooled.

## 7. What success looks like

If the thesis is right, success looks like this:

- **At the engine level**: a single codebase that, with no modification to its core, supports multiple domains in production.
- **At the domain level**: each instance produces insights and actions objectively better than any combination of single-purpose tools.
- **At the trust level**: humans across domains rely on Iris for both observation and action, with the consistent experience that Iris is competent, honest about its limits, and never acts without explicit consent.
- **At the business level**: Iris becomes the default platform for "intelligence and action across systems" in any domain it enters.

## 8. What failure looks like

**The engine cannot stay generic.** Domain-specific concerns leak into the core. Early warning: adding the second domain requires modifying Layer 3 or Layer 4, not just adapters.

**The action layer does not earn trust.** Humans use Iris for observation but never let it act. Early warning: post-launch approval rate stays below 50%.

**The per-domain cost is too high anyway.** Even with good abstractions, each new domain requires too much engineering. Early warning: the second domain takes more than 20% of the time the first took.

**The thesis is correct but the timing is wrong.** Forces in section 6 turn out to be ahead of where they need to be. Early warning: every domain hits the same class of LLM-reliability or compliance blocker.

**The market doesn't value the horizontal abstraction.** Customers prefer vertical products that speak their language. Early warning: every customer asks Iris to "just be the X tool for our domain."

## 9. v0 as the falsifiable experiment

The current build of Iris exists to test the thesis cheaply before committing to a real implementation.

**v0 is not the product. v0 is the experiment.**

What v0 must prove:

1. The five-layer architecture survives contact with real data.
2. The contributor identity model is right.
3. The seam between domain-agnostic and domain-specific holds.
4. The action layer is feasible from this foundation.

What v0 does not need to prove:

- That Iris can scale to many tenants
- That the engine is optimized for any particular workload
- That the UI is good
- That the business model works

Those are the concerns of the next project, the one that takes v0's lessons and implements the thesis properly. v0 is the cheapest possible test of the architectural and conceptual bet.

## 10. Relationship to other documents

This document is the foundation.

- `VISION.md` describes the current implementation of the thesis (the SDLC v0 instance). Each new project gets its own VISION.md.
- `ARCHITECTURE.md` describes the concrete technical structure of the current implementation.
- `CONVENTIONS.md`, `AI_COLLABORATION.md`, and ADRs are implementation-level concerns.
- This document is updated only when the thesis itself shifts.

## 11. Closing

Iris is a bet that the same problem repeats across every domain humans work in, and that the same engine — designed once, carefully — can solve it everywhere. The v0 build tests this bet in the smallest, cheapest way that still produces real evidence. If the bet pays off, what follows is a category-defining platform. If it doesn't, the cost was bounded and the lesson is valuable.

This document is the anchor. Return to it when the work feels lost in details. The details matter, but only insofar as they serve the thesis.

---

*Iris is, before anything else, an argument about what kind of platform should exist. The code is downstream of the argument.*
EOF

echo "==> Writing docs/VISION.md"
cat > docs/VISION.md <<'EOF'
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
EOF

echo "==> Writing docs/ARCHITECTURE.md"
cat > docs/ARCHITECTURE.md <<'EOF'
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
EOF

echo "==> Writing docs/CONVENTIONS.md"
cat > docs/CONVENTIONS.md <<'EOF'
# Iris — Conventions

## Commits
- [Conventional Commits](https://www.conventionalcommits.org/) format
- `type(scope): summary`
- Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `build`, `ci`
- Scope is the service or area: `feat(ingestion): add github webhook handler`
- Body explains the why, not the what
- Reference ClickUp at the end when relevant: `Refs: CU-86b9u2c4g`

## Branches
- `main` is always deployable
- Feature: `feat/<short-description>`
- Fix: `fix/<short-description>`
- Doc: `docs/<short-description>`
- One PR per branch. Short-lived (days, not weeks).

## Pull Requests
- Every PR uses the PR template
- Title format matches commit format
- Description includes the linked ClickUp task and acceptance criteria pasted verbatim
- One AI owns a branch from start to merge — no mid-stream handoffs
- The reviewer checks each acceptance criterion explicitly

## Code style — Go
- `gofmt` and `goimports` on save
- `golangci-lint` clean
- Errors wrapped with context: `fmt.Errorf("loading config: %w", err)`
- No `panic` in service code
- `context.Context` is the first parameter of any I/O function
- Logger is structured (`slog`), passed through context or as parameter — never global

## Testing
- Every service has a `_test.go` next to the code
- Unit tests are the default; integration tests gated by a build tag
- Tests read like specifications, not coverage padding
- PRs adding features without tests must explain why in the PR body

## Error handling
- Errors flow up; recovery happens at the top of the call stack
- HTTP handlers return structured errors with appropriate status codes
- Database errors get wrapped with the triggering operation
- Log at the boundary (service entry/exit), not at every call

## Secrets
- Never committed, ever
- Never logged
- v0: Kubernetes Secrets, manually created
- v1+: external-secrets-operator with a vault provider
- `.env` files for local dev only, in `.gitignore`

## Configuration
- All config via environment variables
- A service must run with sane defaults for local dev
- Production config overlaid via ConfigMaps and Secrets

## Database migrations
- One migration file per change, numbered sequentially
- Forward-only; rollback is a new forward migration
- Tooling: TBD via ADR

## Logging and observability
- Structured logs (JSON in prod, human-readable in dev)
- Every handled event logs: event type, contributor ID, tenant ID, outcome
- Metrics via OpenTelemetry; scraped by Mimir
- Trace IDs propagated across service boundaries
EOF

echo "==> Writing docs/AI_COLLABORATION.md"
cat > docs/AI_COLLABORATION.md <<'EOF'
# Iris — AI Collaboration Model

## Why this document exists
Iris is built by one human and three AI systems. This is the working model that prevents drift, redundant work, and conflicting decisions. Read this before starting any session.

## Roles

### Caleb (human)
- Final authority on direction and merge decisions
- Resolves disagreements between AIs
- Owns the ClickUp board
- Reviews and merges all PRs

### Claude (chat — claude.ai)
- Strategy and architecture decisions
- ClickUp planning (creates folders, lists, stories, subtasks)
- Authors documentation, ADRs, design docs
- Does NOT touch the repo directly. Output is text/markdown Caleb commits.

### Claude Code (in VS Code)
- Implements ClickUp tasks
- Reads CONTEXT, ARCHITECTURE, CONVENTIONS, and the linked ClickUp task at the start of every session
- Writes code, runs tests, opens PRs
- One AI owns a branch start to merge — no mid-stream handoffs
- PRs always use the template; acceptance criteria pasted verbatim from ClickUp

### Codex (in GitHub)
- Reviews PRs against acceptance criteria in the PR body
- Reads [`REVIEW_GUIDE.md`](REVIEW_GUIDE.md) at the start of every review
- Marks each criterion Met / Not Met / Unclear with evidence
- Approves only when all criteria are Met
- Never merges. Approval necessary but not sufficient.

## Communication pattern
AIs do not talk to each other directly. Communication is through artifacts:
- **Code and config** in Git
- **Decisions** in `/docs/adr/`
- **Tasks and state** in ClickUp
- **PR bodies** carry acceptance criteria for the reviewer

When switching context to a new AI, brief it with what's *in the artifacts*, not what the previous AI said.

## Standard flow
1. Claude (chat) creates ClickUp story + subtasks with acceptance criteria
2. Caleb assigns work to Claude Code
3. Claude Code reads CONTEXT, ARCHITECTURE, CONVENTIONS, ClickUp task
4. Claude Code creates a branch, implements, opens a PR using the template
5. Codex reads REVIEW_GUIDE and reviews against pasted criteria
6. Codex approves or requests changes
7. Caleb does final review and merges

## Failure modes

**Confidently wrong about what other AIs did.** An AI won't verify what another AI claimed unless told to. Brief based on artifacts.

**Rubber-stamp reviews.** Codex may approve quickly on large PRs. The fix: explicit criterion-by-criterion review, not "looks good." If a review doesn't address every criterion, Caleb requests a redo.

**Stale criteria.** If criteria change in ClickUp after a PR opens, the PR body must be updated.

**Vague criteria.** "Service handles webhooks reliably" can't be reviewed. "Service returns 200 on valid webhooks, writes to Postgres within 500ms, returns 400 on invalid signatures" can.

**Scope creep flagged as missing.** Codex may say "this PR is missing X" when X was deferred. Fix: clear "Out of scope for this PR" notes in the PR description.

## When AIs disagree
- Document the disagreement explicitly (PR comment, ADR, or task comment)
- Caleb adjudicates
- Architectural decisions go into an ADR

## When this document is wrong
Update it. The doc must match reality.
EOF

echo "==> Writing docs/REVIEW_GUIDE.md"
cat > docs/REVIEW_GUIDE.md <<'EOF'
# Iris — PR Review Guide (for Codex)

## Your role
You are the reviewer for Iris. Verify PRs meet the acceptance criteria in the PR body (copied from the linked ClickUp task). You do NOT merge — Caleb merges. Your approval is necessary but not sufficient.

## Read these first, every session
1. [`CONTEXT.md`](CONTEXT.md) — what Iris is and current state
2. [`ARCHITECTURE.md`](ARCHITECTURE.md) — canonical structure
3. [`CONVENTIONS.md`](CONVENTIONS.md) — code style and discipline
4. The PR description, including the acceptance criteria section

## Review checklist

### 1. Acceptance criteria
For each criterion in the PR body:
- **Met** — diff demonstrably satisfies. Cite file and line.
- **Not Met** — explain what's missing.
- **Unclear** — too vague to evaluate, or diff doesn't clearly address. Ask a specific question.

Criterion-by-criterion table required. "Looks good" is not a review.

### 2. Conventions compliance
- Does code follow `CONVENTIONS.md`?
- Commits in Conventional Commits format?
- Errors wrapped with context?
- Secrets absent from diff?
- Tests present (or absence justified in PR body)?

### 3. Architectural fit
- Does the change respect seam contracts in `ARCHITECTURE.md`?
- Does it introduce coupling between layers that should be separate?
- Does it touch a tenant-isolation boundary? Flag it.

### 4. Scope discipline
- Does the PR do what it says, and only that?
- Scope creep that should be split?
- "Out of scope" notes — are they correct?

### 5. Risk flags
- Database migrations
- Secrets handling changes
- Authentication/authorization changes
- Data retention or audit logging changes
- Changes affecting the contributor identity model

## Output format

```
## Acceptance Criteria
| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | <verbatim from PR body> | Met / Not Met / Unclear | <file:line or explanation> |

## Conventions
- <issue or "no issues">

## Architecture
- <issue or "no issues">

## Scope
- <issue or "scoped correctly">

## Risk Flags
- <flag or "none">

## Decision
APPROVE / REQUEST CHANGES / COMMENT
```

## Decision rules
- **APPROVE** — every criterion Met, no significant issues
- **REQUEST CHANGES** — any criterion Not Met, or any blocking issue
- **COMMENT** — any criterion Unclear, or non-blocking observations

## What you don't do
- You don't merge
- You don't write code or commit fixes
- You don't override "Out of scope for this PR" notes
- You don't approve PRs that don't follow the PR template
- You don't review without reading the docs above

## When in doubt
REQUEST CHANGES with specific questions. Slow review beats sloppy approval.
EOF

echo "==> Writing docs/adr/0000-template.md"
cat > docs/adr/0000-template.md <<'EOF'
# ADR-NNNN: <Short title>

- **Status**: Proposed | Accepted | Deprecated | Superseded by ADR-XXXX
- **Date**: YYYY-MM-DD
- **Deciders**: Caleb, <other contributors>

## Context
What problem are we solving? What forces are at play?

## Decision
What did we decide?

## Consequences
What becomes easier? What becomes harder? What new questions does this raise?

## Alternatives considered
What else did we look at, and why didn't we pick it?
EOF

echo "==> Writing docs/adr/0001-record-architecture-decisions.md"
cat > docs/adr/0001-record-architecture-decisions.md <<'EOF'
# ADR-0001: Record architecture decisions

- **Status**: Accepted
- **Date**: 2026-05-12
- **Deciders**: Caleb

## Context
Iris is a multi-contributor project (one human, three AI systems). Decisions made in chat or in conversation are lost the moment the session ends. Without a durable record, every architectural discussion gets re-litigated, AIs make conflicting choices in different sessions, and Caleb spends time re-explaining decisions instead of building.

## Decision
We will record significant architectural decisions as Architecture Decision Records (ADRs) in `/docs/adr/`, one file per decision, sequentially numbered.

An ADR is warranted when:
- The decision affects more than one service or layer
- The decision constrains future choices
- The decision was non-obvious and required deliberation
- The decision was contested or had multiple reasonable answers

## Consequences

**Easier**:
- Onboarding any new contributor (human or AI) — ADRs explain reasoning behind current shape
- Avoiding circular debates — past decisions documented with rationale
- Audit trail for regulated markets

**Harder**:
- Slight friction to write an ADR for every significant decision
- Need to remember to update or supersede ADRs when decisions change

## Alternatives considered

**Inline comments in code**: invisible to reviewers and contributors not in that file.

**Wiki / external doc tool**: separates decisions from the code they govern. ADRs in the repo travel with the code.

**Verbal decisions**: don't survive across sessions, especially across AI contributors.
EOF

echo "==> Writing docs/adr/README.md"
cat > docs/adr/README.md <<'EOF'
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
EOF

echo "==> Writing .github/pull_request_template.md"
cat > .github/pull_request_template.md <<'EOF'
## Linked ClickUp Task
<!-- Paste the full ClickUp task URL. Format: https://app.clickup.com/t/<task-id> -->

## Summary
<!-- One or two sentences. What does this PR do? -->

## Acceptance Criteria (from ClickUp task — paste verbatim)
<!--
Copy the acceptance criteria section from the ClickUp task body here.
Do not paraphrase. The reviewer (Codex) checks the diff against these exact criteria.
If criteria change in ClickUp after this PR is opened, update this section to match.
-->

- [ ] Criterion 1: <verbatim>
- [ ] Criterion 2: <verbatim>
- [ ] Criterion 3: <verbatim>

## How each criterion is met
<!--
For each criterion above, briefly point to where it's satisfied in this PR.
Format: "Criterion N — <file:line or short explanation>"
-->

## Self-review notes
<!-- Anything non-obvious about the implementation. Tradeoffs, deferred work, follow-ups. -->

## Out of scope for this PR
<!--
Anything the reviewer might expect that's deliberately not in this PR.
The reviewer is instructed to respect this section.
-->

## Testing
<!-- How was this tested? Unit tests, integration, manual verification? -->

## Risk flags
<!--
Anything that could cause incidents:
- Database migrations
- Secrets or auth changes
- Tenant-isolation boundaries
- Audit logging changes
-->

## Reviewer checklist (Codex fills this in)
- [ ] All acceptance criteria reviewed and marked Met / Not Met / Unclear
- [ ] Conventions compliance checked
- [ ] Architecture seam contracts respected
- [ ] Risk flags addressed or noted
EOF

echo "==> Writing scripts/bootstrap-repo.sh placeholder note"
cat > scripts/README.md <<'EOF'
# Scripts

Utility scripts for repo bootstrapping and operations.

The bootstrap script that created this repo's initial structure is preserved here for reference: `bootstrap-repo.sh`. It is idempotent for directory creation but will overwrite files. Do not re-run it after the repo has real work in it.
EOF

# Self-preserve: copy this script into scripts/ for future reference
cp "$0" scripts/bootstrap-repo.sh 2>/dev/null || true

echo ""
echo "==> Done."
echo ""
echo "What was created:"
echo "  README.md"
echo "  .gitignore"
echo "  docs/THESIS.md"
echo "  docs/VISION.md"
echo "  docs/CONTEXT.md"
echo "  docs/ARCHITECTURE.md"
echo "  docs/CONVENTIONS.md"
echo "  docs/AI_COLLABORATION.md"
echo "  docs/REVIEW_GUIDE.md"
echo "  docs/adr/0000-template.md"
echo "  docs/adr/0001-record-architecture-decisions.md"
echo "  docs/adr/README.md"
echo "  docs/setup/.keep (directory)"
echo "  docs/runbooks/.keep (directory)"
echo "  services/.keep (directory)"
echo "  deploy/.keep (directory)"
echo "  scripts/README.md"
echo "  .github/pull_request_template.md"
echo ""
echo "Next steps:"
echo "  1. Review what was created:    git status && ls -la docs/"
echo "  2. Stage everything:           git add ."
echo "  3. Commit:                     git commit -m 'chore: bootstrap repo structure and foundation docs'"
echo "  4. Push:                       git push origin main"
echo ""
echo "After push, the next ClickUp story is configuring branch protection on main."