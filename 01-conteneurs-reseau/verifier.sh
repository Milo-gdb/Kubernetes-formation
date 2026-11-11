#!/usr/bin/env bash
# Vérification du TD 01 — Conteneurs et reverse proxy (Docker requis)
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/lib.sh"
W="${FORMATION_DIR:-$HOME/formation-k8s}/ch01"

titre "TD 01 — Conteneurs et reverse proxy"

if ! commande_existe docker || ! docker info >/dev/null 2>&1; then
  echo "  ❌ Docker n'est pas utilisable par ton utilisateur."
  echo "     ${C_JAUNE}↳ Indice : installe Docker et ajoute-toi au groupe docker (puis reconnecte-toi).${C_RAZ}"
  SCORE_KO=1; bilan
fi

conteneur_actif() { [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" = "true" ]; }
image_de() { docker inspect -f '{{.Config.Image}}' "$1" 2>/dev/null; }

ex1() { conteneur_actif td01-web && [ "$(image_de td01-web)" = "nginx:1.30-alpine" ] && http_local http://localhost:8081 "Welcome to nginx"; }
exercice "Ex.1 — td01-web (nginx:1.30-alpine) répond sur le port 8081" \
  "docker run : pense au mode détaché, au nom du conteneur et à la publication hôte:conteneur." ex1

ex2a() { docker image inspect td01-site:v1 >/dev/null 2>&1; }
exercice "Ex.2a — Image td01-site:v1 construite" \
  "docker build avec l'option qui donne un nom:tag, lancé depuis le dossier du Dockerfile." ex2a

ex2b() { conteneur_actif td01-site && [ "$(image_de td01-site)" = "td01-site:v1" ] && http_local http://localhost:8082 "Ma première image"; }
exercice "Ex.2b — td01-site sert « Ma première image » sur le port 8082" \
  "Le fichier doit remplacer /usr/share/nginx/html/index.html dans l'image ; reconstruis puis relance le conteneur." ex2b

ex3a() {
  docker network inspect td01-net >/dev/null 2>&1 && conteneur_actif td01-backend \
    && docker inspect -f '{{json .NetworkSettings.Networks}}' td01-backend | grep -q td01-net \
    && [ "$(docker inspect -f '{{json .HostConfig.PortBindings}}' td01-backend)" = "{}" ]
}
exercice "Ex.3a — Backend td01-backend sur td01-net, sans port publié" \
  "Crée le réseau puis lance whoami avec l'option --network, sans option -p." ex3a

ex3b() { conteneur_actif td01-proxy && http_local http://localhost:8083 "Hostname:"; }
exercice "Ex.3b — td01-proxy relaie le port 8083 vers le backend" \
  "Le proxy doit être sur le même réseau que le backend, et proxy_pass doit viser son nom de conteneur." ex3b

ex3c() { http_local http://localhost:8083 "X-Real-Ip:"; }
exercice "Ex.3c — Le proxy transmet l'IP du client (X-Real-IP)" \
  "Regarde la directive nginx qui ajoute un en-tête à la requête relayée." ex3c

ex4() {
  local id
  id=$(docker inspect -f '{{.Id}}' td01-web 2>/dev/null) || return 1
  [ "$(tr -d '[:space:]' < "$W/containerd-id.txt" 2>/dev/null)" = "$id" ]
}
exercice "Ex.4 — containerd-id.txt contient l'identifiant containerd de td01-web" \
  "Liste les conteneurs avec ctr dans le namespace containerd utilisé par Docker (voir la mini-leçon)." ex4

bilan
