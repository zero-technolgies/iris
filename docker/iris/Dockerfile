FROM golang:1.26.4-alpine AS builder
WORKDIR /build
COPY src/services/iris/ .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o iris .

FROM scratch
COPY --from=builder /build/iris /iris
EXPOSE 8080
ENTRYPOINT ["/iris"]
