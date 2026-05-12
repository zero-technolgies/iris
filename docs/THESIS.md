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
