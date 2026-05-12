# /deploy

This directory is the GitOps root watched by ArgoCD. All Kubernetes workloads for Iris are defined here.

## Layout

```
deploy/
├── applications/   # ArgoCD child Application manifests (one YAML per Application)
├── charts/         # Helm value overrides and any local charts
└── manifests/      # Raw Kubernetes manifests for workloads not using Helm
```

## Conventions

- One subfolder per Application, named after the Application.
- Inside each folder: `application.yaml` (the ArgoCD Application resource) and any values files or manifests it references.
- `applications/` contains the child Application objects that the root App-of-Apps points at.
- `charts/` contains `values.yaml` overrides for upstream Helm charts, and any fully local charts.
- `manifests/` contains plain YAML for workloads that don't use Helm.
- Empty directories carry a `.keep` file so git tracks them.

## What's not here

Cluster-level infrastructure (cert-manager, ArgoCD) currently lives in `/iac/k8s-config/` as imperative configs from initial bootstrap. This is temporary scaffolding — once Stories 3 and 4 of Epic 2 are complete, these will move under `/deploy/applications/` and `/iac/` will be removed.

Application source code and service definitions live in `/services/`.
