#!/bin/sh
set -e

ORIG_KUBECONFIG=/etc/rancher/k3s/k3s.yaml
KUBECONFIG=/tmp/kubeconfig.yaml

echo "=== Waiting for k3s kubeconfig ==="
until [ -f "$ORIG_KUBECONFIG" ]; do
  echo "  kubeconfig not yet written, waiting..."
  sleep 3
done

cp "$ORIG_KUBECONFIG" "$KUBECONFIG"
# kubeconfig defaults to 127.0.0.1 — point at the k3s-server container
sed -i 's|https://127.0.0.1:6443|https://k3s-server:6443|g' "$KUBECONFIG"
export KUBECONFIG

echo "=== Waiting for k3s API ==="
until /bin/kubectl get nodes >/dev/null 2>&1; do
  echo "  not ready, retrying..."
  sleep 5
done
echo "k3s API ready."
/bin/kubectl get nodes

# ── Argo CD ───────────────────────────────────────────────────────────────────
echo "=== Installing Argo CD ==="
/bin/kubectl create namespace argocd 2>/dev/null || true
/bin/kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "=== Waiting for argocd-server ==="
/bin/kubectl wait deployment argocd-server \
  -n argocd --for=condition=Available --timeout=300s

# Expose Argo CD UI on NodePort 30090 (http://localhost:30090)
/bin/kubectl patch svc argocd-server -n argocd -p \
  '{"spec":{"type":"NodePort","ports":[{"name":"http","port":80,"targetPort":8080,"nodePort":30090,"protocol":"TCP"}]}}'

# ── Argo Rollouts ─────────────────────────────────────────────────────────────
echo "=== Installing Argo Rollouts ==="
/bin/kubectl create namespace argo-rollouts 2>/dev/null || true
/bin/kubectl apply -n argo-rollouts --server-side --force-conflicts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

echo "=== Waiting for argo-rollouts controller ==="
/bin/kubectl wait deployment argo-rollouts \
  -n argo-rollouts --for=condition=Available --timeout=180s

# ── Argo CD Application ───────────────────────────────────────────────────────
echo "=== Creating fake-service Application ==="
cat <<'MANIFEST' | /bin/kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: fake-service
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/nour-sb/sandbox-gitops.git
    targetRevision: HEAD
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
MANIFEST

echo ""
echo "=== Bootstrap complete! ==="
echo ""
echo "  Argo CD UI  → http://localhost:30090"
echo "  Fake service → http://localhost:30080"
echo ""
echo "  Argo CD admin password:"
/bin/kubectl get secret -n argocd argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d && echo ""
