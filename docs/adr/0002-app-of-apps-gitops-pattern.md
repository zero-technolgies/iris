# ADR-0002: App-of-Apps pattern with auto-sync and no-prune

- **Status**: Accepted
- **Date**: 2026-05-12
- **Deciders**: Caleb

## Context

Iris runs on a single k3s cluster managed via ArgoCD. As more services are added, each needs an ArgoCD Application resource. The question is: how are those Application resources themselves managed?

Without a management strategy, each Application must be applied imperatively — a manual step that drifts out of sync with the Git state and breaks the GitOps discipline.

Three related decisions were made together:

1. How to manage multiple ArgoCD Application resources
2. Whether to enable auto-sync
3. Whether to enable prune on auto-sync

## Decision

**App-of-Apps**: A single root Application (`root-app`) watches `/deploy/applications/` and instantiates every child Application manifest it finds there. Adding a new service to ArgoCD means committing a new `application.yaml` under `/deploy/applications/` — no imperative steps.

The root Application itself is the only resource applied imperatively, once, as the bootstrap step that starts the GitOps loop.

**Auto-sync with selfHeal: true**: ArgoCD continuously reconciles cluster state to match Git. Manual changes to Application resources in the cluster (e.g., via the ArgoCD UI) are reverted. This enforces Git as the single source of truth.

**prune: false**: ArgoCD will create and update resources from Git, but will not delete resources that disappear from Git. This is a deliberate safety guard: an accidental commit that removes a file cannot wipe a running workload. Removal is a two-step operation — delete the manifest from Git, then manually prune in ArgoCD.

## Consequences

**Easier**:
- Adding a new application is a single Git commit; no cluster access required
- GitOps discipline enforced by selfHeal — the repo is always authoritative
- No runbook needed for most day-to-day application management

**Harder**:
- Intentional removal of a workload requires an extra manual prune step in ArgoCD (or a separate script)
- The bootstrap step (applying root-app.yaml once) must be documented and repeated when rebuilding the cluster

**New constraints**:
- The root Application must always be healthy for child Applications to be managed
- `/deploy/applications/` must only contain valid ArgoCD Application manifests (or subdirectories of them); invalid YAML will cause the root App to degrade

## Alternatives considered

**Imperative application management**: Apply each Application resource by hand when needed. Rejected — breaks GitOps discipline and does not scale beyond a few applications.

**Helm chart for Application resources**: Wrap all Application definitions in a Helm chart. Rejected — adds Helm rendering complexity to what is structurally just a directory of YAML files. No value at current scale.

**prune: true**: Auto-delete resources removed from Git. Rejected for v0 — the blast radius of an accidental deletion is too high for a solo operator. Revisit when the cluster has more than one person making commits.

**ApplicationSet**: ArgoCD's generator-based pattern for dynamically creating Applications from a template. Rejected for v0 — adds generator configuration complexity that is not warranted for a handful of manually-defined applications. Revisit at v1+ if the number of applications warrants automation.
