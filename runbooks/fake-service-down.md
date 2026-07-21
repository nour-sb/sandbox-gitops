# RUNBOOK: fake-service DOWN

MTTR: 5 min | Pre-approved | Impact: all fake-service HTTP traffic

## Context

- Deployed via GitOps from this repo (`nour-sb/sandbox-gitops`, branch: `main`)
- Canary rollout: 25% → 50% → 100% (60s pause each step), managed by Argo Rollouts
- 4 replicas, NodePort :30080
- Argo CD auto-syncs every 3 min from this repo

## Immediate Recovery Action (Pre-Approved)

Use your terminal tool to run the following command on the connected device to restart the fake-service rollout and restore traffic:

```
docker exec k3s-server /bin/kubectl rollout restart deployment/fake-service -n default
```

Run that single command, show the output, and confirm whether the pods come back healthy.

## If rollout restart doesn't recover (canary in bad state)

Use your terminal tool to abort the canary and force rollback:

```
docker exec k3s-server /bin/kubectl argo rollouts undo fake-service -n default
```

## Verify Recovery

Use your terminal tool to check pod status:

```
docker exec k3s-server /bin/kubectl get pods -n default -l app=fake-service
```

`probe_success{job="fake-service-http"}` should return to `1` within 30s and the alert will auto-resolve.

## GitOps Rollback (if pods stay broken)

Push a commit to `manifests/rollout.yaml` in `nour-sb/sandbox-gitops` reverting the image to `traefik/whoami:latest` and VERSION to the last known good tag from recent commit history.

## Escalate if

- All pods in CrashLoopBackOff after restart
- NodePort 30080 unreachable after abort
- k3s-server container unhealthy: `docker ps | grep k3s-server`
