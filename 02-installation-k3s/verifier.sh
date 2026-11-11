#!/usr/bin/env bash
# Vérification du TD 02 — Installation de k3s
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/lib.sh"
W="${FORMATION_DIR:-$HOME/formation-k8s}/ch02"

titre "TD 02 — Installation de k3s"

k3s_installe() {
  commande_existe k3s || return 1
  ! commande_existe systemctl || systemctl is-active --quiet k3s || systemctl is-active --quiet k3s-agent
}
exercice "Ex.1a — k3s installé et service actif" \
  "Utilise le script officiel puis regarde 'systemctl status k3s' et 'journalctl -u k3s'." k3s_installe

kubeconfig_ok() {
  local f="${KUBECONFIG:-$HOME/.kube/config}"
  [ -f "$f" ] && [ -O "$f" ] && [ "$(stat -c %a "$f")" = "600" ] && cluster_joignable
}
exercice "Ex.2 — kubectl fonctionne sans sudo avec un kubeconfig protégé (600)" \
  "Copie le kubeconfig de k3s dans ton dossier, rends-toi propriétaire et restreins les droits." kubeconfig_ok

exiger_cluster

noeud_ready() {
  $KUBECTL get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -q True
}
exercice "Ex.1b — Au moins un nœud Ready" \
  "kubectl describe node : regarde la section Conditions et les événements." noeud_ready

systeme_ok() {
  pods_running kube-system k8s-app=kube-dns && pods_running kube-system app.kubernetes.io/name=traefik \
    && pods_running kube-system app=local-path-provisioner && pods_running kube-system k8s-app=metrics-server
}
exercice "Ex.3a — CoreDNS, Traefik, local-path-provisioner et metrics-server en Running" \
  "Liste les Pods de kube-system. As-tu désactivé un composant à l'installation ? (INSTALL_K3S_EXEC, /etc/rancher/k3s/config.yaml)" systeme_ok

exercice "Ex.3b — kubectl top fonctionne (metrics-server)" \
  "metrics-server met parfois une minute à collecter ses premières mesures : réessaie." \
  $KUBECTL top nodes

label_ok() { [ -n "$($KUBECTL get nodes -l formation=kubernetes -o name 2>/dev/null)" ]; }
exercice "Ex.4 — Un nœud porte le label formation=kubernetes" \
  "La sous-commande 'kubectl label' s'applique aussi aux nœuds." label_ok

datastore_ok() {
  local reel=sqlite reponse
  reponse=$(tr -d '[:space:]' < "$W/datastore.txt" 2>/dev/null | tr '[:upper:]' '[:lower:]')
  [ -n "$reponse" ] || return 1
  # Indicateur indépendant des droits root : le Pod/label etcd ou l'annotation k3s
  if $KUBECTL get nodes -o jsonpath='{.items[*].metadata.labels}' | grep -q 'node-role.kubernetes.io/etcd'; then reel=etcd; fi
  [ "$reponse" = "$reel" ]
}
exercice "Ex.6 — datastore.txt indique le bon datastore" \
  "Regarde le contenu de /var/lib/rancher/k3s/server/db/ (avec sudo) et relis la mini-leçon etcd." datastore_ok

bilan
