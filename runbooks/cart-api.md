# RUNBOOK: cart-api DOWN

MTTR: 2 min | Severity: critical | Impact: users cannot view or modify their shopping cart

## Architecture & Dependencies

- cart-api `/ready` endpoint proxies to **products-api** — if products-api is down, cart-api probe fails
- This means a cart-api DOWN alert may be caused by products-api being the root cause
- **Always check products-api first**: query `probe_success{job="products-api-http"}` before assuming cart-api itself is broken

## Dependency Check (do this first)

1. Query `probe_success{job="products-api-http"}` — if this is `0`, products-api is the root cause
   - Call get_runbook("products-api") and recover products-api first
   - cart-api will auto-recover once products-api is healthy
2. If `probe_success{job="products-api-http"}` is `1`, then cart-api itself is broken → continue below

## Recovery Steps (only if products-api is healthy)

**Step 1 — Restore replicas via GitOps:**

Update `spec.replicas` to `2` in `manifests/cart-api.yaml` in the `nour-sb/sandbox-gitops` repository on branch `main` and push the change. Argo CD will detect the change and sync within 3 minutes.

**Step 2 — Verify recovery:**

`probe_success{job="cart-api-http"}` should return to `1` within 30s of Argo CD sync.

## Service details

- 2 replicas (Deployment), NodePort :30081
- Argo CD auto-syncs every 3 min from `nour-sb/sandbox-gitops`

## Escalate if

- Pods remain not Running after scale-up
- NodePort 30081 unreachable after recovery
- products-api healthy but cart-api still failing
