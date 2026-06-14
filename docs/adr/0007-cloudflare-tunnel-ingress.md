# ADR-0007: Cloudflare Tunnel ingress for public webhooks

- **Status**: Accepted
- **Date**: 2026-06-14
- **Deciders**: Caleb

## Context

Iris ingestion needs to receive webhooks from public SaaS providers such as GitHub.

The cluster runs on `iris-host` inside a home network. Opening inbound ports on that network would increase operational and security risk. The existing Traefik routes are useful for LAN-accessible services, but GitHub needs a publicly reachable HTTPS endpoint.

The first public endpoint needed is narrow: only `/webhooks/*` should reach the ingestion service.

## Decision

Run `cloudflared` in Kubernetes as an ArgoCD-managed Application at `deploy/applications/cloudflared/`.

The tunnel connector runs in the `postgres` namespace beside the ingestion service. This keeps the origin target simple and avoids cross-namespace routing:

```text
http://ingestion.postgres.svc.cluster.local:8080
```

The tunnel exposes:

```text
https://webhooks.iris.calebache.com/webhooks/*
```

The tunnel ingress config explicitly routes only `/webhooks/.*` and ends with the required catch-all rule:

```yaml
ingress:
  - hostname: webhooks.iris.calebache.com
    path: /webhooks/.*
    service: http://ingestion.postgres.svc.cluster.local:8080
  - service: http_status:404
```

The Cloudflare Tunnel token is stored manually in the `postgres` namespace as `cloudflared-tunnel-token`, key `token`. The token is never committed to Git.

Use Cloudflare-routed DNS for the public tunnel hostname. `calebache.com` remains in Route 53, but Route 53 should delegate `iris.calebache.com` to Cloudflare so Cloudflare can proxy the tunnel hostname:

```text
webhooks.iris.calebache.com -> 5a5e7ea7-d4be-4f5d-a9d5-20a0e522c72a
```

Do not use a DNS-only Route 53 CNAME directly to `<tunnel-id>.cfargotunnel.com` for this endpoint. Runtime testing showed that public resolvers can receive a private `fd10::` tunnel address, which is not reachable from the public internet. Cloudflare must be authoritative/proxying for the public hostname so clients receive Cloudflare public edge addresses.

## Consequences

**Easier**:

- GitHub webhooks can reach Iris without opening inbound ports on the home network.
- The public ingress surface is limited to `webhooks.iris.calebache.com/webhooks/*`.
- The connector is managed by the same App-of-Apps GitOps pattern as the rest of the cluster.
- Keeping cloudflared in the `postgres` namespace avoids extra Kubernetes Service routing complexity for v0.

**Harder**:

- The trust boundary moves outward to Cloudflare's edge. Cloudflare terminates the public connection and forwards traffic through the tunnel.
- Tunnel availability now depends on Cloudflare and on the `cloudflared` connector pod.
- A manual secret must exist before the Deployment can run.
- The DNS records are outside this repo because Route 53 hosts the parent zone and Cloudflare must route the public tunnel hostname.

**Operational constraints**:

- The `cloudflared` image must be pinned, not `latest`. This decision uses `cloudflare/cloudflared:2026.6.0`, the latest GitHub release observed on 2026-06-14.
- Any new public route must be added deliberately to the tunnel ConfigMap. The fallback `http_status:404` rule should remain last.
- Webhook authentication still happens at the ingestion adapter layer; the tunnel is transport, not source authentication.

## Exit path

To remove this public ingress:

1. Delete the Cloudflare public hostname or proxied CNAME for `webhooks.iris.calebache.com`.
2. Delete the Cloudflare Tunnel in the Cloudflare dashboard or with Cloudflare tooling.
3. Remove `deploy/applications/cloudflared/` from Git and let ArgoCD delete or orphan it according to the current prune policy.
4. Delete the runtime Secret:

```sh
kubectl delete secret -n postgres cloudflared-tunnel-token
```

## Alternatives considered

**Open inbound firewall/router ports to Traefik**

Rejected. This exposes the home network directly and requires router/firewall changes. The public webhook use case does not justify that blast radius.

**DNS-only Route 53 CNAME directly to `<tunnel-id>.cfargotunnel.com`**

Rejected after runtime testing. It is simple to create, but public DNS resolution returned only `fd10:aec2:5dae::` for this tunnel target, leaving clients with no public route to port 443.

**Delegate `iris.calebache.com` to Cloudflare**

Accepted for the public webhook subdomain. Route 53 can keep hosting `calebache.com`, while Cloudflare becomes authoritative for `iris.calebache.com` and can proxy `webhooks.iris.calebache.com` to the tunnel.

**Route all ingestion paths through the tunnel**

Rejected. Only `/webhooks/*` needs to be public. The tunnel ConfigMap includes a catch-all `http_status:404` rule so non-webhook paths do not reach ingestion.

**Use GitHub polling instead of webhooks**

Rejected for ingestion. Polling adds latency, creates more moving parts, and can miss event timing. The architecture expects sources to send events forward to Layer 2.
