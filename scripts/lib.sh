#!/usr/bin/env bash
# Bibliothèque commune aux scripts verifier.sh de la formation.
# Usage : source "$(dirname "$0")/../scripts/lib.sh"

KUBECTL="${KUBECTL:-kubectl}"
RESEAU_TIMEOUT="${RESEAU_TIMEOUT:-5}"
SCORE_OK=0
SCORE_KO=0

if [ -t 1 ]; then
  C_VERT=$'\e[32m'; C_ROUGE=$'\e[31m'; C_JAUNE=$'\e[33m'; C_GRAS=$'\e[1m'; C_RAZ=$'\e[0m'
else
  C_VERT=""; C_ROUGE=""; C_JAUNE=""; C_GRAS=""; C_RAZ=""
fi

titre() {
  echo
  echo "${C_GRAS}=== $* ===${C_RAZ}"
}

# exercice "Libellé" "Indice" commande [args...]
# Exécute la commande silencieusement ; ✅ si elle réussit, ❌ + indice sinon.
exercice() {
  local libelle="$1" indice="$2"
  shift 2
  if "$@" >/dev/null 2>&1; then
    echo "  ✅ ${libelle}"
    SCORE_OK=$((SCORE_OK + 1))
  else
    echo "  ❌ ${libelle}"
    echo "     ${C_JAUNE}↳ Indice : ${indice}${C_RAZ}"
    SCORE_KO=$((SCORE_KO + 1))
  fi
}

info() { echo "  ℹ️  $*"; }

bilan() {
  local total=$((SCORE_OK + SCORE_KO))
  echo
  if [ "$SCORE_KO" -eq 0 ]; then
    echo "${C_VERT}${C_GRAS}Bilan : ${SCORE_OK}/${total} vérifications réussies. Bravo !${C_RAZ}"
    exit 0
  else
    echo "${C_ROUGE}${C_GRAS}Bilan : ${SCORE_OK}/${total} vérifications réussies.${C_RAZ} Relis les indices puis relance le script."
    exit 1
  fi
}

# --- Pré-requis --------------------------------------------------------------

commande_existe() { command -v "$1" >/dev/null 2>&1; }

cluster_joignable() {
  commande_existe "$KUBECTL" && $KUBECTL get --raw=/readyz --request-timeout=5s >/dev/null 2>&1
}

exiger_cluster() {
  if ! cluster_joignable; then
    echo "  ❌ Impossible de joindre le cluster avec '$KUBECTL'."
    echo "     ${C_JAUNE}↳ Indice : k3s est-il démarré (systemctl status k3s) ? Ton kubeconfig (~/.kube/config ou \$KUBECONFIG) est-il en place ?${C_RAZ}"
    exit 2
  fi
}

# --- Lecture de l'état du cluster ---------------------------------------------

# kget <namespace> <type/nom> <jsonpath>
kget() {
  $KUBECTL get -n "$1" "$2" -o jsonpath="$3" 2>/dev/null
}

ns_existe() { $KUBECTL get namespace "$1" >/dev/null 2>&1; }

ressource_existe() { # <namespace> <type> <nom>
  $KUBECTL get -n "$1" "$2" "$3" >/dev/null 2>&1
}

# pods_running <namespace> <selecteur> [minimum=1]
pods_running() {
  local min="${3:-1}" n
  n=$($KUBECTL get pods -n "$1" -l "$2" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
  [ "$n" -ge "$min" ]
}

pod_running() { # <namespace> <nom>
  [ "$(kget "$1" "pod/$2" '{.status.phase}')" = "Running" ]
}

pod_pret() { # <namespace> <nom> : tous les conteneurs Ready
  [ "$(kget "$1" "pod/$2" '{.status.conditions[?(@.type=="Ready")].status}')" = "True" ]
}

# deploy_pret <namespace> <nom> [replicas attendus]
deploy_pret() {
  local voulu pret
  voulu="${3:-$(kget "$1" "deployment/$2" '{.spec.replicas}')}"
  pret=$(kget "$1" "deployment/$2" '{.status.readyReplicas}')
  [ -n "$voulu" ] && [ "${pret:-0}" -ge "$voulu" ]
}

replicas_egal() { # <namespace> <type/nom> <n>
  [ "$(kget "$1" "$2" '{.spec.replicas}')" = "$3" ]
}

image_contient() { # <namespace> <type/nom> <motif>
  kget "$1" "$2" '{.spec.template.spec.containers[*].image}{.spec.containers[*].image}' | grep -q -- "$3"
}

svc_a_endpoints() { # <namespace> <service>
  local ips
  ips=$($KUBECTL get endpointslices -n "$1" -l "kubernetes.io/service-name=$2" \
        -o jsonpath='{.items[*].endpoints[?(@.conditions.ready==true)].addresses[*]}' 2>/dev/null)
  [ -n "$ips" ]
}

svc_type() { # <namespace> <service> <type>
  [ "$(kget "$1" "service/$2" '{.spec.type}')" = "$3" ]
}

cle_presente() { # <namespace> <secret|configmap> <nom> <clé>
  local cles
  cles=$($KUBECTL get -n "$1" "$2" "$3" -o go-template='{{range $k, $v := .data}}{{$k}}{{"\n"}}{{end}}' 2>/dev/null)
  echo "$cles" | grep -qx -- "$4"
}

valeur_configmap() { # <namespace> <nom> <clé> <valeur attendue>
  [ "$($KUBECTL get configmap -n "$1" "$2" -o go-template="{{index .data \"$3\"}}" 2>/dev/null)" = "$4" ]
}

pvc_bound() { # <namespace> <nom>
  [ "$(kget "$1" "pvc/$2" '{.status.phase}')" = "Bound" ]
}

# exec_contient <namespace> <pod> <motif> -- commande...
exec_contient() {
  local ns="$1" pod="$2" motif="$3"
  shift 4
  $KUBECTL exec -n "$ns" "$pod" -- "$@" 2>/dev/null | grep -q -- "$motif"
}

# --- Accès HTTP ---------------------------------------------------------------

# http_port_forward <namespace> <type/nom> <port distant> <chemin> [motif attendu]
# Ouvre un port-forward temporaire puis interroge l'URL avec curl.
http_port_forward() {
  local ns="$1" cible="$2" port="$3" chemin="$4" motif="${5:-}" lport pid ok=1 corps
  lport=$(( (RANDOM % 20000) + 30000 ))
  $KUBECTL port-forward -n "$ns" "$cible" "${lport}:${port}" >/dev/null 2>&1 &
  pid=$!
  for _ in $(seq 1 20); do
    if curl -s -o /dev/null --max-time 1 "http://127.0.0.1:${lport}/" 2>/dev/null \
       || curl -sk -o /dev/null --max-time 1 "https://127.0.0.1:${lport}/" 2>/dev/null; then
      break
    fi
    sleep 0.3
  done
  local schema="http"
  [ "$port" = "443" ] || [ "$port" = "8443" ] && schema="https"
  corps=$(curl -skf --max-time "$RESEAU_TIMEOUT" "${schema}://127.0.0.1:${lport}${chemin}" 2>/dev/null) && ok=0
  kill "$pid" >/dev/null 2>&1
  wait "$pid" 2>/dev/null
  [ "$ok" -eq 0 ] || return 1
  [ -z "$motif" ] || echo "$corps" | grep -q -- "$motif"
}

# IP exposée par le contrôleur d'Ingress (Traefik dans k3s par défaut)
ip_ingress() {
  local ip
  ip=$($KUBECTL get ingress -A -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null)
  [ -n "$ip" ] || ip="127.0.0.1"
  echo "$ip"
}

# http_ingress <hôte> <chemin> [motif attendu]
http_ingress() {
  local hote="$1" chemin="$2" motif="${3:-}" corps
  corps=$(curl -sf --max-time "$RESEAU_TIMEOUT" --resolve "${hote}:80:$(ip_ingress)" "http://${hote}${chemin}" 2>/dev/null) || return 1
  [ -z "$motif" ] || echo "$corps" | grep -q -- "$motif"
}

# http_local <url> [motif attendu]
http_local() {
  local corps
  corps=$(curl -sf --max-time "$RESEAU_TIMEOUT" "$1" 2>/dev/null) || return 1
  [ -z "${2:-}" ] || echo "$corps" | grep -q -- "$2"
}
