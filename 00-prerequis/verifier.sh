#!/usr/bin/env bash
# Vérification du TD 00 — Prérequis (aucun cluster nécessaire)
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/lib.sh"
W="${FORMATION_DIR:-$HOME/formation-k8s}/ch00"

titre "TD 00 — Prérequis"

ressources_ok() {
  local cpu ram_mo disque_mo
  cpu=$(nproc)
  ram_mo=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
  disque_mo=$(df -Pm "$HOME" | awk 'NR==2 {print $4}')
  [ "$cpu" -ge 2 ] && [ "$ram_mo" -ge 1800 ] && [ "$disque_mo" -ge 10000 ]
}
exercice "Ex.1 — Machine : ≥ 2 CPU, ≥ 2 Go RAM, ≥ 10 Go libres" \
  "Compare la sortie de nproc, free -h et df -h ~ aux minimums demandés." \
  ressources_ok

outils_ok() {
  for c in curl git ss python3; do commande_existe "$c" || return 1; done
  commande_existe nano || commande_existe vim || commande_existe vi
}
exercice "Ex.2 — Outils curl, git, ss, python3 et un éditeur installés" \
  "Teste chaque outil avec 'command -v <outil>' et installe le paquet manquant." \
  outils_ok

yaml_ok() {
  [ -f "$W/inventaire.yaml" ] || return 1
  python3 - "$W/inventaire.yaml" <<'PY'
import sys
try:
    import yaml
except ImportError:
    sys.exit(3)
d = yaml.safe_load(open(sys.argv[1]))
attendu = {"frontend": 80, "api": 3000, "postgres": 5432}
assert d["application"] == "task-manager"
c = d["composants"]
assert isinstance(c, list) and len(c) == 3
assert {x["nom"]: x["port"] for x in c} == attendu
PY
}
if python3 -c 'import yaml' 2>/dev/null; then
  exercice "Ex.3 — inventaire.yaml valide et complet" \
    "Vérifie la syntaxe (espaces, tirets, ':' suivis d'un espace), les noms exacts et que les ports sont des entiers." \
    yaml_ok
else
  info "Ex.3 ignoré : module Python 'yaml' absent (sudo apt install python3-yaml)."
fi

secret_ok() { [ -f "$W/secret.txt" ] && [ "$(stat -c %a "$W/secret.txt")" = "600" ]; }
exercice "Ex.4a — secret.txt accessible uniquement par son propriétaire" \
  "Regarde les droits avec ls -l : il ne doit rester que rw pour le propriétaire (notation octale)." \
  secret_ok

script_ok() { [ -x "$W/bonjour.sh" ] && [ "$(cd "$W" && ./bonjour.sh 2>/dev/null)" = "Bonjour Kubernetes" ]; }
exercice "Ex.4b — bonjour.sh exécutable et affiche « Bonjour Kubernetes »" \
  "Un script a besoin d'un shebang, du droit x, et doit afficher exactement le texte demandé." \
  script_ok

passerelle_ok() {
  local attendu
  attendu=$(ip route 2>/dev/null | awk '/^default/ {print $3; exit}')
  [ -n "$attendu" ] && [ "$(tr -d '[:space:]' < "$W/passerelle.txt" 2>/dev/null)" = "$attendu" ]
}
exercice "Ex.5a — passerelle.txt contient l'IP de la passerelle par défaut" \
  "La table de routage (ip route) indique la passerelle sur la ligne 'default'." \
  passerelle_ok

exercice "Ex.5b — La résolution DNS fonctionne" \
  "Teste getent hosts kubernetes.io et regarde /etc/resolv.conf." \
  getent hosts kubernetes.io

ports_ok() {
  local p
  for p in 6443 80 443; do
    ss -Htln "sport = :$p" 2>/dev/null | grep -q . || continue
    # Port occupé : acceptable seulement si c'est le cluster k3s qui répond
    cluster_joignable || return 1
  done
}
exercice "Ex.5c — Ports 6443, 80 et 443 libres (ou utilisés par k3s)" \
  "Liste les programmes à l'écoute avec 'sudo ss -tlnp' et arrête celui qui occupe le port." \
  ports_ok

bilan
