# Grafana Assistant Local Demo Stack — Summary

## Goal

Test the **Grafana Assistant Slack app** against real metrics from a locally-run stack. The question: can the AI correctly diagnose incidents, look at the right metrics, and take automated remediation actions?

---

## Phase 1: Stack Setup

**Grafana Cloud org:** `lavenderbanana274.grafana.net` (free tier, AP Southeast region)

**Credentials challenge:** Instance service account token (`glsa_`) works only for Grafana UI APIs — can't push metrics to Mimir. A separate **Access Policy token** from `grafana.com` with `metrics:write` scope + correct region (prod-ap-southeast-1) was needed. First token was created in US region, causing cross-region auth failures.

**Docker Compose stack** at `/Users/nour/sandbox/grafana/`:

| Service | Image | Role |
|---|---|---|
| `node-exporter` | `prom/node-exporter` | Host CPU/memory/disk metrics |
| `nginx` | `nginx:alpine` | The "production service" |
| `blackbox` | `prom/blackbox-exporter` | HTTP probing — up/down + latency |
| `alloy` | `grafana/alloy` | Scrapes all, remote_writes to Grafana Cloud |
| `k3s-server` | `rancher/k3s` | Full Kubernetes in Docker |
| `k3s-bootstrap` | `rancher/k3s` | One-shot: installs Argo CD + Rollouts |

**Alloy scrape jobs:**
- `node-exporter:9100` (15s interval)
- `blackbox → nginx:80` (10s interval) → `probe_success{job="nginx-http"}`
- `blackbox → k3s-server:30080` (10s interval) → `probe_success{job="fake-service-http"}`
- `alloy:12345` self-metrics (15s interval)

**Alert rules created:**
- `High CPU - Demo Alert` — actually `go_goroutines > 10` (demo only, fires continuously)
- `nginx-service DOWN` — `probe_success{job="nginx-http"} < 1`, 30s for
- `fake-service DOWN` — `probe_success{job="fake-service-http"} < 1`, 2m for — with embedded runbook URL in annotation

**Dashboard:** `https://lavenderbanana274.grafana.net/d/claude-demo-host/claude-demo-host-metrics`

---

## Phase 2: First Grafana Assistant Tests (Slack)

**Question asked:** `@Grafana can you check if our network consumption is normal?`

**Assistant correctly:**
- Identified the step-function spike at 12:15–12:30 UTC (exactly when docker-compose started)
- Characterized it as "sustained increase, not a transient spike"
- Linked the cause to container startup

**Incident simulation #1 — nginx down:**
- Stopped nginx container
- `probe_success` dropped to 0, alert fired
- Asked `@Grafana Is the service down?`
- **Assistant got it wrong** — checked `up` metric (always 1 while blackbox runs) instead of `probe_success`. Classic metric confusion.
- Asked specifically about `probe_success{job="nginx-http"}` → assistant correctly diagnosed
- After nginx was restarted, assistant **auto-generated a Grafana dashboard** (6 panels) and created it at `https://lavenderbanana274.grafana.net/d/prj9c6v`

**Auto-investigation enrichment:**
- Grafana Assistant offered to attach an auto-investigation enrichment to the `nginx-service DOWN` alert rule
- Enrichment approved — registers a trigger so IRM auto-runs the analysis when the alert fires next time
- Limitation: enrichment only fires when the incident is created _through_ the alert rule (API-created IRM incidents aren't automatically linked)

---

## Phase 3: Canary + GitOps Incident Scenario

Added **k3s + Argo CD + Argo Rollouts** to the stack:
- Deployed `fake-service` as a canary rollout (25% / 75% stable)
- Pushed bad image tag (`traefik/whoami:v99.0.0-bad-release`) → `ErrImagePull` → `probe_success=0`
- Alert fired: `fake-service DOWN`
- Runbook embedded in alert annotation, instructing the assistant to read it via GitHub MCP and trigger a workflow dispatch

**Assistant behavior:**
- Read the runbook from GitHub ✓
- Identified that it needed to trigger a GitHub Actions workflow dispatch ✓
- **Correctly refused to auto-act** from data in the alert description ("this came from the alert, not from you") — asked for human approval
- When asked to proceed, hit the **step limit** (~10-20 tool calls) before completing the GitHub push
- GitHub MCP scope: has `read` + `push_files` but not `workflow_dispatch`

**Workaround discussed:** Maintain a `STABLE_VERSION` file in the repo updated by each deploy — reduces assistant steps from 5 to 2 (read file → push commit).

---

## Phase 4: Grafana Assistant Tunnel

Explored connecting local kubectl/docker to the Assistant:

- Discovered `grafana-assistant` CLI has native **tunnel** feature (`grafana-assistant tunnel connect --terminal`)
- Installed via brew, authenticated against `lavenderbanana274` instance
- The tunnel exposes local shell commands to Grafana Assistant — no cloudflared needed

**Slack bot token problem:**
- Claude was using an `xoxb-` bot token to message Grafana in Slack
- Grafana Assistant ignores bot messages (anti-loop safeguard)
- Real user token (`xoxp-`) needed for the assistant to respond
- User provided `xoxp-` token but it was missing `chat:write` scope — session ended before completing this loop

---

## Key Findings

| Finding | Detail |
|---|---|
| **Metric confusion** | Assistant checked `up` not `probe_success` on first try — probe-based monitoring requires explicit metric naming in queries/runbooks |
| **Auto-dashboard generation** | Assistant created a 6-panel dashboard directly in Grafana Cloud mid-investigation |
| **Step limit is real** | ~10-20 tool calls max per request. Complex GitOps rollback (read runbook → find version → push commit) hits this |
| **IRM enrichment needs native alert linkage** | API-created IRM incidents don't auto-trigger enrichments — only alert-rule-fired incidents do |
| **Bot anti-loop** | Grafana Assistant ignores Slack bot messages — requires real user token (`xoxp-`) to automate |
| **GitHub MCP scope** | Has read + file push, no `workflow_dispatch` — direct file commits to gitops repo work as alternative |
| **Assistant Tunnel** | Native CLI (`grafana-assistant tunnel connect --terminal`) exposes local shell to the AI |

## Open / Incomplete

- Tunnel test not completed (Slack user token scope issue)
- `STABLE_VERSION` file pattern not implemented in sandbox-gitops repo
- Auto-enrichment full loop (alert fires → IRM incident auto-created → enrichment auto-runs) not fully verified
