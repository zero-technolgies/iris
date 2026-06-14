# Setup 03: ArgoCD as Source

Epic 4 makes ArgoCD the first runtime source for Iris.

The goal is to turn ArgoCD sync and health notifications into durable Layer 2 events. Those events become the runtime half of the v0 correlation spine: GitHub and CI events explain what code was produced, while ArgoCD events explain what revision actually reached the cluster.

See also:

- [ADR-0006: ArgoCD event delivery via webhooks and MCP](../adr/0006-argocd-event-delivery.md)
- [ArgoCD ingestion operations runbook](../runbooks/argocd-ingestion-operations.md)

## What This Epic Built

The end-to-end shape is:

```text
ArgoCD Application event
  -> argocd-notifications-controller
  -> POST /webhooks/argocd on ingestion
  -> ingestion Receiver validates and parses
  -> events table row with source='argocd'
```

The ArgoCD side is configured in `deploy/applications/argocd/values.yaml` through the ArgoCD Helm chart's notifications values. That config renders into `argocd-notifications-cm`.

The ingestion side registers `/webhooks/argocd` and stores each accepted notification as an immutable event row. The event payload remains raw JSON so Layer 3 can decide which fields to promote into correlation facts.

## Why `target_revision` Matters

`target_revision` is the commit SHA ArgoCD reports for the synced Application revision.

That field is load-bearing for Epic 5 Correlation. It is the join key between:

- code-world events, such as GitHub push, PR merge, CI build, and image publication
- runtime-world events, such as ArgoCD sync success, sync failure, unknown sync status, or degraded health

Without `target_revision`, Iris can still know that an Application changed, but it cannot reliably answer the important question: "Which commit is running now, and what happened after it deployed?"

For v0, `target_revision` stays inside the raw event payload. Layer 3 can later materialize it into structured deployment facts without changing Layer 2 ingestion.

## Notification Configuration

ArgoCD notifications are configured through the self-managed ArgoCD Application:

```text
deploy/applications/argocd/application.yaml
deploy/applications/argocd/values.yaml
```

The values file defines:

- `notifications.enabled: true`
- webhook service `service.webhook.iris-ingestion`
- global subscription for all Applications
- triggers:
  - `on-sync-succeeded`
  - `on-sync-failed`
  - `on-sync-status-unknown`
  - `on-health-degraded`
- templates:
  - `template.iris-sync-succeeded`
  - `template.iris-sync-failed`
  - `template.iris-sync-status-unknown`
  - `template.iris-health-degraded`

The webhook target is the in-cluster service DNS name:

```text
http://ingestion.postgres.svc.cluster.local:8080/webhooks/argocd
```

The webhook includes:

```text
X-Iris-Webhook-Secret: $iris-webhook-secret
```

ArgoCD resolves `$iris-webhook-secret` from `argocd-notifications-secret` in the `argocd` namespace. The ingestion service validates against the same value injected from `ingestion-argocd-webhook-secret` in the `postgres` namespace.

## Why Global Subscriptions

The root App-of-Apps creates child ArgoCD Applications, but notification annotations on the root Application do not propagate to those child Application resources.

For that reason, Epic 4 uses a global subscription in `argocd-notifications-cm` instead of per-Application annotations. This covers every Application ArgoCD processes and avoids requiring each child Application manifest to repeat the same notification annotation.

## Two Paths for ArgoCD

ADR-0006 defines the two-path model:

- **Webhook push path**: ArgoCD pushes sync and health events into Layer 2 ingestion.
- **MCP pull path**: future Layer 5 agent tooling can query live ArgoCD state on demand.

The push path is for durable event capture. The pull path is for interactive operational questions. Both use ArgoCD as a source, but they serve different layers and should not be collapsed into one mechanism.

## Implementation Lessons

### Helm Values May Not Be Live Values

During implementation, the repo values file looked correct before the live `argocd-notifications-cm` matched it. Because ArgoCD is self-managed through Helm, debug with both rendered and live views:

```sh
helm template argocd argo/argo-cd \
  --version 7.6.12 \
  --namespace argocd \
  -f deploy/applications/argocd/values.yaml \
  --show-only templates/argocd-configs/argocd-notifications-cm.yaml

helm get values argocd -n argocd
```

Use the first command to verify what Git should render. Use the second to verify what the live Helm release actually has.

### Auto-Sync Can Need a Forced Sync

ArgoCD can get stuck if Application comparison fails. During Epic 4, a `terminatingReplicas` schema comparison error left sync status `Unknown` and blocked normal auto-sync.

When the ArgoCD Application is self-managing and auto-sync is stuck, force the sync:

```sh
argocd app sync argocd --force --replace
```

Use this only when the Application status shows comparison errors and ordinary auto-sync is not moving the release forward.

### YAML Block Scalars Do Not Escape Go Templates

The notification templates originally used this expression for "current time":

```gotemplate
{{(call .time.Now).Format \"2006-01-02T15:04:05Z07:00\"}}
```

Inside a YAML block scalar (`|`), the backslashes are literal. ArgoCD's Go template parser received `\"` and failed with:

```text
unexpected "\\" in operand
```

The fix was to use `{{.app.status.reconciledAt}}` for `sync_status_unknown` and `health_degraded` timestamps. It is populated by ArgoCD, RFC3339-compatible, and close enough to "now" for status events emitted during reconciliation.

## Current Runtime Secrets

The shared webhook secret is intentionally not committed.

Create or rotate it with:

```sh
SECRET_VALUE=$(openssl rand -hex 32)

kubectl patch secret argocd-notifications-secret -n argocd \
  --type=merge -p "{\"stringData\":{\"iris-webhook-secret\":\"${SECRET_VALUE}\"}}"

kubectl create secret generic ingestion-argocd-webhook-secret \
  -n postgres \
  --from-literal=secret="${SECRET_VALUE}" \
  --dry-run=client -o yaml | kubectl apply -f -
```

Both keys must contain the same value:

- `argocd/argocd-notifications-secret`, key `iris-webhook-secret`
- `postgres/ingestion-argocd-webhook-secret`, key `secret`
