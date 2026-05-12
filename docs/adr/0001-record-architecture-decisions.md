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
