# RUNBOOK: fake-service DOWN

MTTR: 5 min | Pre-approved | Impact: all fake-service HTTP traffic

## Context

- Deployed via GitOps from `nour-sb/sandbox-gitops`, branch `main`
- Canary rollout managed by Argo Rollouts: 25% → 50% → 100% (60s pause each step)
- 4 replicas, exposed via NodePort :30080
- Argo CD auto-syncs every 3 min

## Immediate Recovery Action (Pre-Approved)

Call `terminal_execute` directly — DO NOT call `filesystem_list_projects` first, it is unnecessary. Use this exact command:

```
docker exec k3s-server /bin/kubectl rollout restart deployment/fake-service -n default
```

## If rollout restart fails (canary in bad state)

Call `terminal_execute` with:

```
docker exec k3s-server /bin/kubectl argo rollouts undo fake-service -n default
```

## Verify Recovery

Call `terminal_execute` with:

```
docker exec k3s-server /bin/kubectl get pods -n default -l app=fake-service
```

`probe_success{job="fake-service-http"}` should return to `1` within 30s.

## GitOps Rollback (pods stay broken)

Push a commit to `manifests/rollout.yaml` in `nour-sb/sandbox-gitops` reverting the image tag to the last known-good version from git history.

## Escalate if

- All pods CrashLoopBackOff after restart
- NodePort 30080 unreachable after abort
- k3s-server unhealthy: `docker ps | grep k3s-server`
