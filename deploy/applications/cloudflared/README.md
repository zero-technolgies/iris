# cloudflared

This ArgoCD Application runs a Cloudflare Tunnel connector in the `postgres` namespace so public webhook providers can reach Iris ingestion without opening inbound ports on the home network.

## Runtime Secret

Create the Cloudflare Tunnel in the Cloudflare dashboard or with `cloudflared tunnel create`, then store the tunnel token manually:

```sh
kubectl create secret generic cloudflared-tunnel-token \
  -n postgres \
  --from-literal=token='<cloudflare tunnel token>' \
  --dry-run=client -o yaml | kubectl apply -f -
```

Do not commit the tunnel token.

## DNS

`calebache.com` is managed in Route 53, but the public tunnel hostname must still be routed through Cloudflare DNS/proxying. A Route 53 DNS-only CNAME directly to `<tunnel-id>.cfargotunnel.com` is not sufficient for this tunnel because public resolvers can receive a private `fd10::` tunnel address instead of Cloudflare public edge addresses.

Use Route 53 only to delegate the `iris.calebache.com` subdomain to Cloudflare, then create the tunnel public hostname in Cloudflare:

```text
webhooks.iris.calebache.com -> 5a5e7ea7-d4be-4f5d-a9d5-20a0e522c72a
```

In practice, create or delegate the `iris.calebache.com` zone in Cloudflare, then add `webhooks.iris.calebache.com` as a public hostname for the tunnel or as a proxied CNAME to `5a5e7ea7-d4be-4f5d-a9d5-20a0e522c72a.cfargotunnel.com`.

## Public Test

After the Secret, DNS record, and ArgoCD sync are complete:

```sh
curl -i -X POST https://webhooks.iris.calebache.com/webhooks/argocd \
  -H 'X-Iris-Webhook-Secret: <value>' \
  -H 'Content-Type: application/json' \
  --data-binary @src/services/ingestion/internal/sources/argocd/testdata/sync_succeeded.json
```

Expected response:

```text
HTTP/2 202
```

Any non-`/webhooks/` path should return a Cloudflare Tunnel `404`.
