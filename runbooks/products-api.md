# RUNBOOK: products-api DOWN

MTTR: 2 min | Severity: critical | Impact: product catalog unavailable; cart-api may fail to resolve product details

## Context

- Returns product catalog (GET /) — used by cart-api and frontend
- Deployed via GitOps from `nour-sb/sandbox-gitops`, branch `main`
- 3 replicas (Argo Rollout, canary), NodePort :30080
- Argo CD auto-syncs every 3 min

## Recovery Steps

**Step 0 — Check cart-api dependency:**

Run get_runbook("cart-api") — if cart-api is also down it may be an infra issue, not products-api-specific.

**Step 1 — Restore replicas via GitOps:**

Update `spec.replicas` to `3` in `manifests/products-api.yaml` in the `nour-sb/sandbox-gitops` repository on branch `main` and push the change. Argo CD will detect the change and sync within 3 minutes.

**Step 2 — Verify recovery:**

`probe_success{job="products-api-http"}` should return to `1` within 30s of Argo CD sync. Alert auto-resolves.

## Escalate if

- Pods remain not Running after scale-up
- NodePort 30080 unreachable after recovery
- k3s-server container unhealthy: `docker ps | grep k3s-server`
