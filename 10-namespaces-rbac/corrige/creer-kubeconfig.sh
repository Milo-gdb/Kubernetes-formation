#!/usr/bin/env bash
# Fabrique un kubeconfig pour le ServiceAccount td-10/lecteur.
set -euo pipefail
SORTIE="${1:-$HOME/formation-k8s/ch10/lecteur.kubeconfig}"
mkdir -p "$(dirname "$SORTIE")"
SERVEUR=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
JETON=$(kubectl create token lecteur -n td-10 --duration=24h)

cat > "$SORTIE" <<FIN
apiVersion: v1
kind: Config
clusters:
  - name: formation
    cluster:
      server: ${SERVEUR}
      certificate-authority-data: ${CA}
users:
  - name: lecteur
    user:
      token: ${JETON}
contexts:
  - name: lecteur@formation
    context:
      cluster: formation
      user: lecteur
      namespace: td-10
current-context: lecteur@formation
FIN
chmod 600 "$SORTIE"
echo "Kubeconfig écrit dans $SORTIE"
