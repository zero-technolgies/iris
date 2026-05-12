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
