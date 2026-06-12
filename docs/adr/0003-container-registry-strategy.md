# ADR-0003: Container registry strategy

- **Status**: Proposed
- **Date**: 2026-06-03
- **Deciders**: Caleb

## Context

Iris needs a container registry to store built images. The CI pipeline (GitHub Actions) pushes images after build; the k3s cluster pulls them at deploy time via ArgoCD.

The repo lives under the `zero-technolgies` GitHub organization. The cluster is a single-node k3s instance on a LAN-only host. There is no public ingress to the cluster.

Key constraints:
- GHCR free plan allows 500 MB storage and 1 GB data transfer per month
- v0 has one service (and later a small handful); image count is low
- The repo is public; images are build artifacts, not proprietary source
- GitHub Actions is the CI platform; it has native GHCR integration
- The cluster is LAN-only — a self-hosted registry would not be reachable from GitHub-hosted runners without exposing it publicly or adding a self-hosted runner

## Decision

Use GitHub Container Registry (GHCR) with public packages and the built-in `GITHUB_TOKEN` for push. No pull credentials on the cluster side.

Specifically:

1. **Registry**: GHCR at `ghcr.io/zero-technolgies/`
2. **Push authentication**: `GITHUB_TOKEN` (automatic in GitHub Actions, has `write:packages` by default for the same repo). No PAT needed.
3. **Package visibility**: public. Anyone can pull without authentication.
4. **Pull authentication**: none required. No Kubernetes image-pull Secrets, no service account patches.
5. **Image size discipline**: all Go services use multi-stage Docker builds with `scratch` or `gcr.io/distroless/static` as the final stage. Target: 10–20 MB per image.
6. **Tagging strategy**: git SHA for traceability, plus `latest` for convenience. Old tags are prunable.
7. **Storage management**: at 10–20 MB per image, 500 MB accommodates ~25 versions. Prune old tags manually for now; automate via GitHub Actions if volume increases.

## Consequences

**Easier**:
- Zero credential management on the cluster side
- No infrastructure to deploy or maintain for the registry
- Native CI integration — no custom Docker login steps beyond what `GITHUB_TOKEN` provides
- Public images double as portfolio artifacts

**Harder**:
- 500 MB storage limit requires image size discipline and periodic cleanup
- 1 GB transfer limit means large images or frequent pulls could hit the cap (mitigated by small images and ArgoCD's pull-on-change-only pattern)
- If images ever need to be private, the cluster side needs a pull secret and the CI side may need a PAT — that's a new story, not a tweak
- No built-in vulnerability scanning (GHCR doesn't include Trivy or equivalent; GitHub's Dependabot covers source deps but not container layers)

## Alternatives considered

**Harbor (self-hosted on iris-host)**: full-featured registry with vulnerability scanning, RBAC, and replication. Rejected for v0 because GitHub Actions runners can't reach a LAN-only registry without exposing it publicly or running a self-hosted runner. The infrastructure overhead doesn't earn its weight at single-user scale. Revisit for v1 if a self-hosted runner is added or public ingress is enabled.

**Azure Container Registry (ACR)**: natural fit for the planned v2 migration to AKS. Rejected for v0 because it adds an Azure dependency and cost ($5+/month for Basic tier) when GHCR is free and sufficient.

**Docker Hub**: free tier available but rate-limited on pulls (100 pulls/6 hours for anonymous). GHCR has no pull rate limit for public packages and integrates natively with the CI platform already in use.

**Private GHCR packages**: would require a PAT or `GITHUB_TOKEN` with `read:packages` scope, plus Kubernetes image-pull Secrets in every namespace. Rejected because the images contain compiled Go binaries, not secrets or proprietary source. Public visibility is appropriate and eliminates all pull-side credential management.