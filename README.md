# sandbox-grafana

Local demo stack for testing Grafana Assistant. Full summary in [SUMMARY.md](SUMMARY.md).

## Architecture

> Animated interactive version: [stack-diagram.html](stack-diagram.html) (open locally)

```mermaid
flowchart TD
    subgraph gh ["☁ GitHub / External"]
        GHA["GitHub Actions\nworkflow_dispatch"]
        GHR["GitHub Repo\nnour-sb/sandbox-gitops"]
    end

    subgraph dc ["🐳 Docker Compose · localhost"]
        NE["node-exporter\n:9100"]
        GW["api-gateway\nnginx :8080"]
        BB["blackbox\nHTTP prober :9115"]
        ALLOY["Alloy\n:12345"]
        RB["runbook-mcp\n:3001"]
    end

    subgraph k8s ["⎈ Kubernetes · k3s · Argo CD · Rollouts"]
        ARGOCD["Argo CD\n:30090"]
        ROLLOUT["Argo Rollouts\ncanary 25%→100%"]
        PROD["products-api\n:30080 · 3r"]
        CART["cart-api\n:30081 · 2r"]
    end

    subgraph gc ["📊 Grafana Cloud"]
        GRAFANA["lavenderbanana274\nMimir · Dashboards · Alerting"]
        AI["@Grafana AI\nAssistant"]
    end

    subgraph sl ["💬 Slack"]
        SLACK["@Grafana\nincident response"]
    end

    NE -->|scrape| ALLOY
    ALLOY -->|scrape| BB
    BB -->|probe| GW
    BB -->|probe :30080| PROD
    BB -->|probe :30081| CART
    ALLOY -->|remote_write| GRAFANA
    GHA -->|push manifests| GHR
    GHR -->|poll 3 min| ARGOCD
    ARGOCD -->|trigger| ROLLOUT
    ROLLOUT -->|deploy canary| PROD
    ARGOCD -->|deploy| CART
    GRAFANA -->|alert| SLACK
    GHA -->|annotate| GRAFANA
    AI -->|get_runbook · tunnel| RB
    SLACK <-->|chat| AI
```

## Stack

Docker Compose: node-exporter, nginx, blackbox-exporter, Grafana Alloy, k3s, Argo CD, Argo Rollouts.  
Metrics remote-write → `lavenderbanana274.grafana.net` (Grafana Cloud free tier, AP Southeast).

## Structure

| Path | Purpose |
|---|---|
| `docker-compose.yml` | Full local stack |
| `config.alloy` | Alloy scrape + remote_write config |
| `alerts/` | Grafana alert rule JSON (provisioning API) |
| `manifests/` | Kubernetes manifests (Argo CD GitOps) |
| `runbooks/` | Alert runbooks |
| `runbook-mcp/` | Local MCP server exposing runbooks to Grafana Assistant |
| `SUMMARY.md` | Full testing journal and findings |
| `MILESTONES.md` | Feature milestone tracker |
