# iris

The Iris service — Layer 2 (Ingestion) of the Iris platform.

## What it is

This is the permanent home of the Iris backend service. In its current form (Epic 2, v0) it is a minimal HTTP server that proves the GitOps loop end-to-end: code → CI → image → ArgoCD → running container.

It will grow into the full ingestion layer in Epic 3, receiving webhooks from GitHub, ArgoCD, and other sources, normalizing events into a common envelope, and persisting them for correlation.

## Role in the architecture

```
Sources → [Ingestion] → Correlation → Insights → Interface
               ↑
           this service
```

Iris sits at Layer 2. It receives raw events from external sources and normalises them into the common event envelope (timestamp, contributor ID, tenant ID, event type, payload). Nothing upstream reads from sources directly; nothing downstream reads raw events — they go through this layer.

## Endpoints

| Method | Path      | Response                  |
|--------|-----------|---------------------------|
| GET    | `/`       | `Iris`                    |
| GET    | `/healthz`| `{"status":"healthy"}`    |

## Configuration

| Env var | Default | Description        |
|---------|---------|--------------------|
| `PORT`  | `8080`  | HTTP listener port |

## Running locally

```sh
# From repo root
go run ./src/services/iris/

# Or via Docker (build context is repo root)
docker build -f docker/iris/Dockerfile -t iris:local .
docker run -p 8080:8080 iris:local
```

## Testing

```sh
cd src/services/iris
go test ./...
```
