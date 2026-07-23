# RUNBOOK: fake-service DOWN

MTTR: 2 min | Severity: critical | Impact: all fake-service HTTP traffic

## Context

- Deployed via GitOps from `nour-sb/sandbox-gitops`, branch `main`
- 4 replicas, NodePort :30080
- Argo CD auto-syncs every 3 min

## Recovery Steps

**Step 1 — Restore replicas via GitOps:**

Update `spec.replicas` to `4` in `manifests/rollout.yaml` in the `nour-sb/sandbox-gitops` repository on branch `main` and push the change. Argo CD will detect the change and sync within 3 minutes, restoring the service.

**Step 2 — Verify pods are recovering:**

```
docker exec k3s-server /bin/kubectl get pods -n default -l app=fake-service --kubeconfig /etc/rancher/k3s/k3s.yaml
```

`probe_success{job="fake-service-http"}` should return to `1` within 30s of Argo CD sync. Alert auto-resolves.

## Escalate if

- Pods remain not Running after scale-up
- NodePort 30080 unreachable after recovery
- k3s-server container unhealthy: `docker ps | grep k3s-server`
