# RUNBOOK: fake-service DOWN

MTTR: 2 min | Severity: critical | Impact: all fake-service HTTP traffic

## Context

- Deployed via GitOps from `nour-sb/sandbox-gitops`, branch `main`
- 4 replicas, NodePort :30080
- Argo CD auto-syncs every 3 min

## Recovery Steps

**Step 1 — Scale replicas back to 4:**

```
docker exec k3s-server /bin/kubectl patch rollout fake-service -n default --kubeconfig /etc/rancher/k3s/k3s.yaml --type=json -p='[{"op":"replace","path":"/spec/replicas","value":4}]'
```

**Step 2 — Verify pods are recovering:**

```
docker exec k3s-server /bin/kubectl get pods -n default -l app=fake-service --kubeconfig /etc/rancher/k3s/k3s.yaml
```

`probe_success{job="fake-service-http"}` should return to `1` within 30s. Alert auto-resolves.

## Escalate if

- Pods remain not Running after scale-up
- NodePort 30080 unreachable after recovery
- k3s-server container unhealthy: `docker ps | grep k3s-server`
