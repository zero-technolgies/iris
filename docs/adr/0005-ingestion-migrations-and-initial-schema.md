# ADR-0005: Ingestion migrations and initial schema

- **Status**: Proposed
- **Date**: 2026-06-12
- **Deciders**: Caleb

## Context

Iris needs a durable Layer 2 event store before source ingestion, correlation, or insights can be implemented. The schema has to preserve tenant boundaries, treat humans and agents as first-class contributors, and keep raw source payloads without forcing a table change for every new webhook shape.

ADR-0004 chooses Postgres via CloudNativePG for the backing database. This ADR defines how the ingestion schema is migrated into that Postgres database and records the initial event envelope schema.

Key constraints:
- Every domain table must carry tenant context, except the `tenants` table that defines the tenant boundary itself
- Contributors include humans and agents without downstream special-casing
- Raw events need immutable storage with source-specific details retained as JSONB
- Migrations must be runnable locally and from Kubernetes
- The migration tool should be boring, maintained, and easy to replace if needed

## Decision

Use `golang-migrate` v4.19.1 for database migrations. The GitHub release page lists v4.19.1 as the latest release as of 2026-06-12.

Specifically:

1. **Migration tool**: `github.com/golang-migrate/migrate/v4` at `v4.19.1`.
2. **Migration location**: `src/services/ingestion/migrations`.
3. **Runner**: a small Go command at `src/services/ingestion/cmd/migrate` that reads `DATABASE_URL` and optional `MIGRATIONS_PATH`.
4. **Kubernetes execution**: a PreSync Kubernetes Job runs the migration command before the future ingestion rollout. It reads the CloudNativePG-generated `iris-postgres-app` Secret from the `postgres` namespace.
5. **Initial tables**:
   - `tenants`
   - `contributors`
   - `events`
6. **Enums**:
   - `contributor_type`: `human`, `coding_agent`, `voice_agent`, `review_agent`, `unknown`
   - `event_source`: `github`, `github_actions`, `argocd`, `kubernetes`, `grafana`
7. **Seed data**: a seed migration creates the default `Iris` tenant and Caleb's human contributor record.

## Vision query review

The schema can express the current demo questions in `docs/VISION.md`.

**Use case 1: Codex approvals followed by bugs**

The event log can store GitHub PR reviews, deployments, and bug events in `events`, while contributor identity lives in `contributors`.

```sql
WITH codex_approvals AS (
    SELECT
        e.tenant_id,
        e.occurred_at AS approved_at,
        e.payload->>'pull_request_number' AS pr_number,
        e.payload->>'merge_commit_sha' AS merge_commit_sha
    FROM events e
    JOIN contributors c
      ON c.tenant_id = e.tenant_id
     AND c.id = e.contributor_id
    WHERE e.tenant_id = $1
      AND e.source = 'github'
      AND e.event_type = 'pull_request_review'
      AND c.type = 'review_agent'
      AND c.display_name = 'Codex'
      AND e.payload->>'state' = 'approved'
      AND e.occurred_at >= now() - interval '30 days'
),
bugs AS (
    SELECT
        tenant_id,
        occurred_at AS bug_at,
        payload->>'merge_commit_sha' AS merge_commit_sha
    FROM events
    WHERE tenant_id = $1
      AND event_type = 'bug_filed'
)
SELECT a.pr_number, a.approved_at, b.bug_at
FROM codex_approvals a
JOIN bugs b
  ON b.tenant_id = a.tenant_id
 AND b.merge_commit_sha = a.merge_commit_sha
 AND b.bug_at >= a.approved_at
 AND b.bug_at < a.approved_at + interval '7 days';
```

Layer 4 can later materialize this into a `pr_outcomes` insight table, but Layer 2 can store the underlying facts.

**Use case 2: approved action dispatch**

The action flow can be represented as events with tenant and contributor attribution:
- voice directive from a `human` contributor
- approval event from the same `human`
- dispatch event attributed to the orchestrator or `voice_agent`
- implementation PR event attributed to a `coding_agent`
- review event attributed to a `review_agent`
- merge event attributed to the final human approver

All of those records fit the same `events` envelope and can be correlated by IDs stored in `payload`, such as ClickUp task ID, branch name, PR number, commit SHA, or action request ID.

## Consequences

**Easier**:
- Migrations can run the same way locally and in Kubernetes
- Tenant filtering is supported by the primary event indexes from the first migration
- Contributor identity is modeled once and reused across sources
- JSONB payloads allow new source events without immediate schema churn

**Harder**:
- Raw event queries depend on payload key conventions until Layer 3 and Layer 4 create structured facts
- JSONB allows malformed source payloads unless ingestion validates event-type contracts before insert
- The migration Job depends on the future ingestion image packaging migrations at `/app/migrations`

## Alternatives considered

**Hand-written SQL applied manually**: rejected because it does not give repeatable local and cluster execution, version tracking, or a clean path for CI/CD.

**ORM-managed migrations**: rejected for v0. Iris does not have an ORM and the schema is small enough that explicit SQL is clearer.

**Goose**: viable, but rejected because `golang-migrate` is widely used, has simple file-based migrations, and works cleanly as a tiny command or container entrypoint.

**Atlas**: powerful, but too much tool for the current scope. Declarative schema management may be worth revisiting when the schema grows.
