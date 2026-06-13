# Ingestion

Layer 2 receives source events, normalizes them into the Iris event envelope, and stores them immutably.

## HTTP server

The server entrypoint lives at `cmd/ingestion`.

### Endpoints

- `GET /healthz` pings Postgres through the connection pool and returns `200` when the dependency is reachable.
- `GET /readyz` returns `200` when the process is ready to receive traffic.

For this skeleton both endpoints are intentionally small. The intended split is that `healthz` answers whether the process and required dependencies are healthy enough to keep running, while `readyz` answers whether Kubernetes should route traffic to this instance.

### Config

Configuration is read from environment variables:

- `PORT`: HTTP port, defaults to `8080`
- `DATABASE_URL`: required Postgres connection string
- `LOG_LEVEL`: `debug`, `info`, `warn`, or `error`; defaults to `info`
- `ENV`: `prod` or `production` enables JSON logs; any other value uses text logs for local development

### Run

Start a local Postgres 18 container:

```sh
docker run --rm --name iris-ingestion-postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=iris -p 55432:5432 postgres:18
```

Run the server:

```sh
DATABASE_URL='postgres://postgres:postgres@localhost:55432/iris?sslmode=disable' go run ./cmd/ingestion
```

Check the endpoints:

```sh
curl -fsS http://localhost:8080/healthz
curl -fsS http://localhost:8080/readyz
```

### Build

Build the server binary:

```sh
go build ./cmd/ingestion
```

Build the runtime image:

```sh
docker build -f ../../../docker/ingestion-server/Dockerfile -t iris-ingestion-server:local ../../..
```

## Webhook framework

Generic webhook handling lives in `internal/ingest`.

Source adapters implement:

```go
type Receiver interface {
    ValidateSignature(req *http.Request) error
    Parse(body []byte) ([]Event, error)
}
```

The HTTP server wires receivers by URL path, such as `/webhooks/github` or `/webhooks/argocd`. This story registers no real source adapters yet; later source stories add receivers to that route map.

For v0, events default to the seeded Iris tenant ID:

```text
00000000-0000-0000-0000-000000000001
```

Run the webhook integration test against a migrated local Postgres:

```sh
DATABASE_URL='postgres://postgres:postgres@localhost:55435/iris?sslmode=disable' go test -tags integration ./internal/ingest
```

## Migrations

Migrations use `golang-migrate` through the local runner in `cmd/migrate`.

```sh
DATABASE_URL='postgres://iris:password@localhost:5432/iris?sslmode=disable' go run ./cmd/migrate up
DATABASE_URL='postgres://iris:password@localhost:5432/iris?sslmode=disable' go run ./cmd/migrate version
```

Set `MIGRATIONS_PATH` when running from outside this service directory:

```sh
MIGRATIONS_PATH='file://src/services/ingestion/migrations' DATABASE_URL='postgres://iris:password@localhost:5432/iris?sslmode=disable' go run ./src/services/ingestion/cmd/migrate up
```
