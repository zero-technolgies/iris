# Runbook: ArgoCD Ingestion Operations

Use this runbook when ArgoCD notifications are not reaching Iris ingestion, when ArgoCD auto-sync appears stuck, or when notification template changes need validation.

See also:

- [Setup 03: ArgoCD as Source](../setup/03-argocd-as-source.md)
- [ADR-0006: ArgoCD event delivery via webhooks and MCP](../adr/0006-argocd-event-delivery.md)

## Quick Health Check

Check the notifications controller is running:

```sh
kubectl get deployment -n argocd argocd-notifications-controller
```

Check recent notification activity:

```sh
kubectl logs -n argocd deployment/argocd-notifications-controller --since=15m \
  | rg -i 'sending notification|failed|error|warn|iris'
```

Healthy processing usually includes `Start processing` and `Processing completed` lines for Applications. A real notification delivery path should include `Sending notification` lines when a trigger fires.

Check recent ArgoCD events in Postgres:

```sh
POSTGRES_POD=$(kubectl get pod -n postgres \
  -l cnpg.io/cluster=iris-postgres \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n postgres "$POSTGRES_POD" -- \
  psql -d iris -c "
    select occurred_at, event_type, payload->>'application_name' as application_name,
           payload->>'target_revision' as target_revision
    from events
    where source = 'argocd'
    order by occurred_at desc
    limit 10;
  "
```

If the database name, pod name, or user changes, inspect the CloudNativePG cluster and app Secret before running the query:

```sh
kubectl get cluster -n postgres
kubectl get secret -n postgres iris-postgres-app -o yaml
```

## Validate Notification Template Config

Render the exact notifications ConfigMap from Git:

```sh
helm template argocd argo/argo-cd \
  --version 7.6.12 \
  --namespace argocd \
  -f deploy/applications/argocd/values.yaml \
  --show-only templates/argocd-configs/argocd-notifications-cm.yaml
```

Use this before changing notification templates. It catches YAML and Helm rendering issues before ArgoCD applies them.

The bug to avoid:

```gotemplate
{{(call .time.Now).Format \"2006-01-02T15:04:05Z07:00\"}}
```

Do not use escaped quotes inside YAML block scalar template actions. The backslashes are passed literally and ArgoCD fails with:

```text
unexpected "\\" in operand
```

For status events, use:

```gotemplate
{{.app.status.reconciledAt}}
```

## Check Live Helm Values

If `deploy/applications/argocd/values.yaml` looks correct but the live ConfigMap does not match, check what Helm values the live release has:

```sh
helm get values argocd -n argocd
```

Check the live ConfigMap:

```sh
kubectl get configmap -n argocd argocd-notifications-cm -o yaml
```

If Git render and live ConfigMap disagree, ArgoCD may not have synced the self-managed ArgoCD Application yet.

## Forced Sync When Auto-Sync Is Stuck

First inspect the ArgoCD Application:

```sh
kubectl get application -n argocd argocd -o yaml \
  | rg -n 'sync:|status:|ComparisonError|terminatingReplicas|message:'
```

Signs auto-sync is stuck:

- `sync.status: Unknown`
- `ComparisonError` in Application status
- errors mentioning `terminatingReplicas`
- rendered Helm values in Git do not appear in the live release

When those are present, force the self-managed ArgoCD Application sync:

```sh
argocd app sync argocd --force --replace
```

Use this for ArgoCD self-management drift or comparison errors. Do not use it as the normal deployment path for ordinary application changes.

After the forced sync:

```sh
argocd app get argocd
kubectl get configmap -n argocd argocd-notifications-cm -o yaml
kubectl logs -n argocd deployment/argocd-notifications-controller --since=10m \
  | rg -i 'error|warn|unexpected|template'
```

## Troubleshoot Missed Sync Events

### 1. Check Notification Deduplication

ArgoCD notifications use `oncePer` to avoid sending duplicate notifications. The controller stores notification state on Application annotations.

Inspect annotations:

```sh
kubectl get application -n argocd iris -o yaml \
  | rg -n 'notifications.argoproj.io|oncePer|notified'
```

To force re-delivery for a single Application during debugging, remove notification state annotations from that Application:

```sh
kubectl annotate application -n argocd iris \
  notifications.argoproj.io/last-notified-on-sync-succeeded- \
  notifications.argoproj.io/last-notified-on-sync-failed- \
  notifications.argoproj.io/last-notified-on-sync-status-unknown- \
  notifications.argoproj.io/last-notified-on-health-degraded-
```

If the actual annotation names differ, list them first and remove the exact keys shown by the cluster.

### 2. Verify Both Webhook Secrets Exist

ArgoCD sends:

```text
X-Iris-Webhook-Secret: <shared value>
```

The value must exist in both places:

```sh
kubectl get secret argocd-notifications-secret \
  -n argocd \
  -o jsonpath='{.data.iris-webhook-secret}{"\n"}' | wc -c

kubectl get secret ingestion-argocd-webhook-secret \
  -n postgres \
  -o jsonpath='{.data.secret}{"\n"}' | wc -c
```

Both commands should print a non-zero length. Matching lengths are a quick sanity check, but they do not prove the decoded values match.

Rotate both values together if needed:

```sh
SECRET_VALUE=$(openssl rand -hex 32)

kubectl patch secret argocd-notifications-secret -n argocd \
  --type=merge -p "{\"stringData\":{\"iris-webhook-secret\":\"${SECRET_VALUE}\"}}"

kubectl create secret generic ingestion-argocd-webhook-secret \
  -n postgres \
  --from-literal=secret="${SECRET_VALUE}" \
  --dry-run=client -o yaml | kubectl apply -f -
```

Do not print or commit `SECRET_VALUE`.

### 3. Verify Ingestion Is Reachable

Port-forward ingestion:

```sh
kubectl port-forward -n postgres svc/ingestion 8080:8080
```

In another terminal, post a fixture payload with the correct secret value:

```sh
curl -i -X POST http://localhost:8080/webhooks/argocd \
  -H 'X-Iris-Webhook-Secret: <value>' \
  -H 'Content-Type: application/json' \
  --data-binary @src/services/ingestion/internal/sources/argocd/testdata/sync_succeeded.json
```

Expected result:

```text
HTTP/1.1 202 Accepted
```

Then verify a new event row:

```sh
POSTGRES_POD=$(kubectl get pod -n postgres \
  -l cnpg.io/cluster=iris-postgres \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n postgres "$POSTGRES_POD" -- \
  psql -d iris -c "
    select occurred_at, source, event_type, payload->>'target_revision' as target_revision
    from events
    where source = 'argocd'
    order by ingested_at desc
    limit 5;
  "
```

## Common Failure Modes

### Template Parse Error: `unexpected "\\" in operand`

Cause: escaped quotes inside a Go template action in a YAML block scalar.

Fix: remove the quoted function call or replace the field with `{{.app.status.reconciledAt}}`.

Validate:

```sh
helm template argocd argo/argo-cd \
  --version 7.6.12 \
  --namespace argocd \
  -f deploy/applications/argocd/values.yaml \
  --show-only templates/argocd-configs/argocd-notifications-cm.yaml
```

### Notification Config Does Not Match Git

Cause: the self-managed ArgoCD Application has not applied the new Helm values, or auto-sync is blocked.

Check:

```sh
helm get values argocd -n argocd
kubectl get application -n argocd argocd -o yaml | rg -n 'ComparisonError|Unknown|terminatingReplicas'
```

Fix if stuck:

```sh
argocd app sync argocd --force --replace
```

### No New Event Rows

Check in order:

1. Notifications controller logs show trigger and send activity.
2. The live `argocd-notifications-cm` points to `http://ingestion.postgres.svc.cluster.local:8080/webhooks/argocd`.
3. Both webhook Secrets exist and contain matching values.
4. Ingestion pod is running and has `ARGOCD_WEBHOOK_SECRET` populated from `ingestion-argocd-webhook-secret`.
5. Manual port-forward curl returns `202 Accepted`.
6. Database query shows a new `source='argocd'` row.
