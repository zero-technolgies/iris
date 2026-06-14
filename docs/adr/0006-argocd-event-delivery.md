# ADR-0006: ArgoCD event delivery via webhooks and MCP

- **Status**: Accepted
- **Date**: 2026-06-14
- **Deciders**: Caleb

## Context

Iris needs ArgoCD data in two different ways.

Layer 2 ingestion needs durable deployment events. These events are the runtime side of the v0 correlation spine: GitHub and CI describe what code was produced, while ArgoCD sync events describe what revision was applied to the cluster. The `target_revision` field from an ArgoCD sync event is the commit SHA that lets Layer 3 join code-world events to runtime-world state.

Future Layer 5 interface tooling will also need to inspect ArgoCD live state on demand. That is a different workflow: an agent or CLI asks a question, gets the current ArgoCD answer, and uses it to explain or operate the system.

Those two workflows have different delivery requirements. Ingestion wants low-latency, append-only, forward-moving events. Interface tooling wants query-time access to current state.

## Decision

Use ArgoCD notification webhooks for Layer 2 ingestion.

ArgoCD is configured to push selected sync and health notifications to the ingestion service at `/webhooks/argocd`. The ingestion service validates the shared webhook secret, parses the notification payload, and stores one immutable `events` row with:

- `source = 'argocd'`
- `event_type` from the notification template
- `occurred_at` from the notification timestamp
- raw JSON payload containing `application_name`, `target_revision`, `source_repo`, `sync_status`, and event-specific fields

Use MCP-based ArgoCD querying later for Layer 5 agent tooling.

This is the two-path model for the same source:

- **Push path**: ArgoCD notification webhooks feed Layer 2 ingestion.
- **Pull path**: MCP queries expose live ArgoCD state to future Layer 5 interface tooling.

This is intentional, not contradictory. ArgoCD is a Layer 1 source in two modes because the consuming layers need different behaviors.

## Consequences

**Easier**:

- Layer 2 receives events as they happen instead of polling for changes.
- There is no polling loop to schedule, operate, or backfill.
- Event flow matches the architecture rule that sources send events forward to ingestion.
- The `target_revision` commit SHA is captured at the moment ArgoCD reports sync or health state, preserving the join key Layer 3 needs for Epic 5 correlation.
- Layer 5 remains free to use MCP for live operational questions without coupling ingestion to query-time behavior.

**Harder**:

- Notification templates become part of the ingestion contract. A template typo can break event delivery.
- Notification deduplication matters. ArgoCD `oncePer` settings can suppress repeat notifications until the relevant notification annotation is cleared or the dedupe key changes.
- Shared-secret setup is operationally required in two places: `argocd/argocd-notifications-secret` key `iris-webhook-secret` and `postgres/ingestion-argocd-webhook-secret` key `secret`.
- Delivery is asynchronous. A successful sync and a successful stored event are related but not the same signal; operators must verify both the notification controller and the ingestion database.

**Operational lessons from implementation**:

- The notification timestamp templates originally used `(call .time.Now).Format \"2006-01-02T15:04:05Z07:00\"` inside YAML block scalars. YAML block scalars pass backslashes literally, so ArgoCD's Go template parser saw `\"` and failed with `unexpected "\\" in operand`. PR #25 replaced those templates with `{{.app.status.reconciledAt}}`.
- Helm values can appear correct in Git while the live ArgoCD-managed release still has older rendered config. When the generated `argocd-notifications-cm` does not match the values file, compare rendered values with `helm template`, then inspect live values with `helm get values argocd -n argocd`.
- ArgoCD auto-sync can get stuck behind comparison errors. During implementation, a `terminatingReplicas` schema comparison error caused sync status to remain `Unknown` and blocked normal reconciliation. A forced sync of the ArgoCD Application was required to move the self-managed release forward.
- Global notification subscriptions were used because annotations on the root App-of-Apps do not propagate to child Application resources.

## Alternatives considered

**MCP-only polling for Layer 2 ingestion**

Rejected for Layer 2. MCP is useful for future query-time interface tooling, but using it as the only ingestion path would make event capture pull-based. That adds polling latency, creates a poller to operate, and risks losing event timing or missing events while the poller is down.

**Direct ArgoCD API polling**

Rejected for the same Layer 2 reasons as MCP-only polling, with additional coupling to ArgoCD API details. Polling the API would require Iris to infer events by comparing snapshots rather than receiving the event ArgoCD already knows how to emit.

**Per-Application notification annotations**

Rejected for v0 operations. It would require every Application manifest to carry notification annotations and would not solve App-of-Apps propagation. A global subscription in `argocd-notifications-cm` is simpler and covers all Applications consistently.
