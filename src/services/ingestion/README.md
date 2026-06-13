# Ingestion

Layer 2 receives source events, normalizes them into the Iris event envelope, and stores them immutably.

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
