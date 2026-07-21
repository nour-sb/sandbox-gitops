# RUNBOOK: fake-service DOWN

MTTR: 5 min | Severity: critical | Impact: all fake-service HTTP traffic

## Context

- Deployed via GitOps from `nour-sb/sandbox-gitops`, branch `main`
- Canary rollout managed by Argo Rollouts: 25% → 10s pause → 100%
- 4 replicas, NodePort :30080
- Argo CD auto-syncs every 3 min

## Recovery Steps

**Step 1 — Rollback the canary via terminal:**

```
docker exec k3s-server /bin/kubectl-argo-rollouts undo fake-service -n default
```

**Step 2 — Verify pods are recovering:**

```
docker exec k3s-server /bin/kubectl get pods -n default -l app=fake-service
```

`probe_success{job="fake-service-http"}` should return to `1` within 60s. Alert auto-resolves.

**Step 3 — If canary rollback fails, restart the deployment:**

```
docker exec k3s-server /bin/kubectl rollout restart deployment/fake-service -n default
```

## GitOps Rollback (if terminal steps fail)

Push a commit to `manifests/rollout.yaml` in `nour-sb/sandbox-gitops` reverting the image tag to the last known-good version from git history. Argo CD will sync within 3 min.

## Escalate if

- All pods remain in CrashLoopBackOff or ImagePullBackOff after rollback
- NodePort 30080 unreachable after recovery
- k3s-server container unhealthy: `docker ps | grep k3s-server`
