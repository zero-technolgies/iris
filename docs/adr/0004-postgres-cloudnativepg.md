# ADR-0004: Postgres via CloudNativePG

- **Status**: Proposed
- **Date**: 2026-06-12
- **Deciders**: Caleb

## Context

Iris needs Postgres for the event store, correlation data, and insights backing store. The cluster is a single-node k3s environment managed through ArgoCD's app-of-apps pattern, so Postgres should be declared in Git and reconciled by ArgoCD instead of installed manually.

Key constraints:
- The database must run in-cluster for v0
- The operator and database should be separate ArgoCD Applications
- CloudNativePG CRDs are large, so ArgoCD must use server-side apply for the operator Application
- Storage starts at 50 GiB and must be backed by SSD-class local storage
- The Postgres data volume must be expandable
- HA, backup, and PITR are intentionally out of scope for this story

## Decision

Use the CloudNativePG operator to manage Postgres.

Specifically:

1. **Operator**: ArgoCD Application `cloudnative-pg` installs the `cloudnative-pg` Helm chart from `https://cloudnative-pg.github.io/charts` at chart version `0.28.3` / app version `1.29.1`.
2. **ArgoCD apply mode**: the operator Application uses `ServerSideApply=true` to avoid CRD size issues.
3. **Database**: ArgoCD Application `postgres` applies raw manifests from `deploy/applications/postgres/manifests`.
4. **Cluster name**: `iris-postgres`.
5. **Postgres version**: major version 18 using `ghcr.io/cloudnative-pg/postgresql:18`. PostgreSQL 18.4 is the latest stable minor release listed by postgresql.org as of 2026-06-12; PostgreSQL 19 is still beta.
6. **Topology**: one Postgres instance for v0.
7. **Database and owner**: bootstrap database `iris` with owner `iris`.
8. **Application credentials**: rely on CloudNativePG's generated Secret `iris-postgres-app`, which includes the application username, password, and connection URI fields for the bootstrapped database.
9. **Storage**: use a dedicated `local-path-ssd` StorageClass with `50Gi` initial size, `Retain` reclaim policy, and `allowVolumeExpansion: true`.

The `local-path-ssd` StorageClass uses the existing k3s local-path provisioner. This records the intended SSD-backed class separately from the cluster's default `local-path` class, which is not marked expandable. The node's physical disk backing still needs to be verified on the host because Kubernetes does not expose whether `/var/lib/rancher/k3s/storage` is SSD or HDD.

## Consequences

**Easier**:
- Database lifecycle is reconciled by ArgoCD
- Postgres credentials are generated and rotated by CloudNativePG instead of being committed to Git
- Future HA, backup, and PITR work can build on CloudNativePG primitives
- The database Application is small and readable because the operator owns StatefulSet and PVC details

**Harder**:
- Postgres startup depends on the CloudNativePG operator and CRDs being installed first
- Single-instance Postgres has no HA for v0
- Backup and PITR are not available until a follow-up story configures them
- Local-path storage ties the database to the current node
- The SSD backing for local-path must be confirmed operationally on the host

## Alternatives considered

**Bitnami PostgreSQL Helm chart**: rejected. Broadcom's 2025 Bitnami packaging changes moved free images toward a legacy/unmaintained path and put maintained secure images behind a paid offering. Iris should not depend on `docker.io/bitnami/postgresql` for a new database deployment.

**Raw StatefulSet**: rejected for v0. A hand-written StatefulSet would make bootstrap, credentials, readiness, failover evolution, and future backup integration our responsibility. CloudNativePG gives us a maintained Postgres control plane without much manifest complexity.

**Managed cloud Postgres**: rejected for v0 because the current cluster is local k3s and the goal is to exercise the GitOps path in-cluster. Revisit during the v2 cloud migration.
