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

Cluster-level infrastructure is being moved out of imperative bootstrap config and into ArgoCD. cert-manager is managed from `/deploy/applications/cert-manager/`; ArgoCD and remaining bootstrap manifests still live in `/iac/k8s-config/` until the Epic 2 migration stories are complete.

Application source code and service definitions live in `/services/`.
