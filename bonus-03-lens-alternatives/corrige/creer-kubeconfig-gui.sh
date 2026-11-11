#!/usr/bin/env bash
# Crée ~/formation-k8s/bonus03/kubeconfig-gui pour le ServiceAccount kube-system/gui-lecture
set -euo pipefail
SORTIE="${1:-$HOME/formation-k8s/bonus03/kubeconfig-gui}"
mkdir -p "$(dirname "$SORTIE")"

kubectl create serviceaccount gui-lecture -n kube-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create clusterrolebinding gui-lecture --clusterrole=view \
  --serviceaccount=kube-system:gui-lecture --dry-run=client -o yaml | kubectl apply -f -

SERVEUR=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
TOKEN=$(kubectl create token gui-lecture -n kube-system --duration=24h)

umask 077
cat > "$SORTIE" <<FIN
apiVersion: v1
kind: Config
clusters:
  - name: formation
    cluster:
      server: ${SERVEUR}
      certificate-authority-data: ${CA}
users:
  - name: gui-lecture
    user:
      token: ${TOKEN}
contexts:
  - name: formation-lecture
    context:
      cluster: formation
      user: gui-lecture
      namespace: task-manager
current-context: formation-lecture
FIN
chmod 600 "$SORTIE"
echo "Kubeconfig écrit : $SORTIE"
