FROM golang:1.26.4-alpine AS builder
WORKDIR /build
COPY src/services/ingestion/ .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o ingestion-migrate ./cmd/migrate

FROM scratch
WORKDIR /app
COPY --from=builder /build/ingestion-migrate /app/ingestion-migrate
COPY --from=builder /build/migrations /app/migrations
USER 65532:65532
ENTRYPOINT ["/app/ingestion-migrate"]
