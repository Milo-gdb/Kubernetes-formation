#!/usr/bin/env bash
# Vérification du TD bonus 01 — k9s
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/lib.sh"
NS=k9s-lab
FICHIER="${HOME}/formation-k8s/bonus01/diagnostic.txt"
KCFG="${KUBECONFIG:-$HOME/.kube/config}"
KCFG="${KCFG%%:*}"

titre "TD bonus 01 — k9s"

exercice "Ex.1a — k9s est installé" \
  "La commande k9s doit être dans le PATH (binaire des releases GitHub ou gestionnaire de paquets)." \
  bash -c 'k9s version -s | grep -q Version'

kubeconfig_valide() {
  [ -f "$KCFG" ] && [ -n "$($KUBECTL config current-context 2>/dev/null)" ] && cluster_joignable \
    && [ "$(stat -c %a "$KCFG")" = 600 ]
}
exercice "Ex.1b — kubeconfig valide (contexte courant, cluster joignable, droits 600)" \
  "Contrôle le contexte courant, la connexion au cluster et les permissions du fichier kubeconfig." kubeconfig_valide

exiger_cluster

pf_8080() { curl -sf --max-time "$RESEAU_TIMEOUT" http://127.0.0.1:8080/ | grep -qi "task"; }
exercice "Ex.2 — Port-forward local 8080 vers le frontend du fil rouge actif" \
  "Depuis la vue des Services, k9s sait créer un port-forward ; laisse k9s ouvert pendant la vérification." pf_8080

exercice "Ex.3a — Scénario de panne déployé (namespace k9s-lab)" \
  "Lance d'abord le scénario fourni dans bonus-01-k9s/scenario/." ressource_existe $NS deployment postgres

diag() { [ -s "$FICHIER" ] && grep -qi "crashloop" "$FICHIER" && grep -qi "password" "$FICHIER"; }
exercice "Ex.3b — Diagnostic rédigé (statut et cause)" \
  "Le fichier doit mentionner le statut du Pod et la cause trouvée dans les logs du conteneur précédent." diag

repare() { deploy_pret $NS postgres 1 && deploy_pret $NS api 1 \
  && [ "$(kget $NS deployment/postgres '{.spec.template.spec.containers[0].image}')" = "postgres:17-alpine" ]; }
exercice "Ex.3c — PostgreSQL réparé et API de nouveau prête" \
  "Toutes les informations nécessaires existent déjà dans le namespace : regarde la vue :secrets." repare

bilan
