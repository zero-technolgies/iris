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

`calebache.com` is managed in Route 53, so use a Route 53 CNAME instead of delegating `iris.calebache.com` to Cloudflare:

```text
webhooks.iris.calebache.com CNAME <tunnel-id>.cfargotunnel.com
```

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
