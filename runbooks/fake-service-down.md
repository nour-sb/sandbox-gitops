# RUNBOOK: fake-service DOWN

MTTR: 5 min | Pre-approved | Impact: all fake-service HTTP traffic

## Recovery — do these steps in order, no investigation needed

**Step 1 — Rollback the canary. Call `terminal_execute` directly with:**

```
docker exec k3s-server /bin/kubectl argo rollouts undo fake-service -n default
```

DO NOT call `filesystem_list_projects` first — it is not needed.

**Step 2 — Verify recovery with `terminal_execute`:**

```
docker exec k3s-server /bin/kubectl get pods -n default -l app=fake-service
```

`probe_success{job="fake-service-http"}` returns to `1` within 60s — alert auto-resolves.

**Step 3 — If rollback fails (rollout stuck), use `terminal_execute`:**

```
docker exec k3s-server /bin/kubectl rollout restart deployment/fake-service -n default
```

## GitOps rollback (if all terminal steps fail)

Push a commit to `manifests/rollout.yaml` in `nour-sb/sandbox-gitops` reverting the image tag to the last known-good version from git history.

## Context

- GitOps repo: `nour-sb/sandbox-gitops`, branch `main`
- Argo CD auto-syncs every 3 min
- Canary: 25% → 10s pause → 100%, managed by Argo Rollouts
- NodePort :30080, 4 replicas
