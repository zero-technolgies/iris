FROM golang:1.26.4-alpine AS builder
WORKDIR /build
COPY src/services/ingestion/ .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o ingestion ./cmd/ingestion

FROM scratch
COPY --from=builder /build/ingestion /ingestion
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/ingestion"]
