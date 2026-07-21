# RUNBOOK: fake-service DOWN

MTTR: 5 min | Pre-approved | Impact: all fake-service HTTP traffic

## Context

- Deployed via GitOps from this repo (`nour-sb/sandbox-gitops`, branch: `main`)
- Canary rollout: 25% → 50% → 100% (60s pause each step), managed by Argo Rollouts
- 4 replicas split between stable + canary pods during rollout
- Argo CD auto-syncs every 3 min from this repo
- **Versioning convention**: tags follow semver — `vMAJOR.MINOR.PATCH` (e.g. `v1.0.0`, `v2.0.0`, `v3.0.0`)

## Step 1 — Check Rollout Status

```
docker exec k3s-server /bin/kubectl get rollout fake-service -n default
docker exec k3s-server /bin/kubectl get pods -n default -l app=fake-service
```

## Step 2 — Check Pod Logs

```
docker exec k3s-server /bin/kubectl logs -l app=fake-service -n default --tail=50
```

## Step 3 — Abort Bad Canary (if rollout in progress)

```
docker exec k3s-server /bin/kubectl argo rollouts abort fake-service -n default
```

Shifts 100% traffic back to stable immediately.

## Step 4 — Rollback via GitOps (RECOMMENDED)

Rollback is done by re-triggering the deploy workflow with the **previous stable version tag**.

To find the last stable version: look at recent commits on `main` in this repo — find the last successful deploy commit before the bad one. The version tag is in the commit message (e.g. `deploy: v2.0.0`).

Then trigger the GitHub Actions workflow dispatch:

- **Repository**: `nour-sb/sandbox-gitops`
- **Workflow**: `.github/workflows/deploy.yml`
- **Input**: `version` = previous stable tag (e.g. `v2.0.0`)

Use your GitHub tool to trigger this workflow dispatch directly. Argo CD will auto-sync the resulting commit within 3 min and update the rollout.

## Step 5 — Emergency kubectl rollback (bypasses GitOps)

Only use if GitHub Actions is unavailable:

```
docker exec k3s-server /bin/kubectl argo rollouts undo fake-service -n default
```

**Warning**: cluster and git will diverge — push a matching version commit to this repo after recovery.

## Step 6 — Verify Recovery

- `probe_success{job="fake-service-http"}` returns to `1` within 30s
- Alert auto-resolves in Grafana
- Argo CD UI: http://localhost:30090/applications/fake-service

## Escalate if

- All pods in CrashLoopBackOff (not just canary)
- NodePort 30080 unreachable after abort
- k3s-server container unhealthy: `docker ps | grep k3s-server`
