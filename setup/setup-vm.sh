#!/usr/bin/env bash
# Prépare l'environnement de la formation Kubernetes, en deux modes :
#   VM    (Ubuntu Server 22.04/24.04) : SSH, paquets de base, clone du dépôt, résumé (IP, ssh, snapshot).
#   hôte  (Ubuntu ou Arch Linux)      : client SSH, entrée task-manager.local dans /etc/hosts, test de la VM.
# Le mode est détecté automatiquement (Arch ou Ubuntu avec bureau → hôte, Ubuntu Server virtualisé → VM).
# N'installe volontairement NI k3s, NI kubectl (chapitre 02), NI Helm (chapitre 12), NI k9s (bonus 01).
# Idempotent : peut être relancé sans risque.
# Usage : bash setup-vm.sh                          # mode détecté automatiquement
#         bash setup-vm.sh --vm                     # force le mode VM
#         bash setup-vm.sh --hote [IP_VM] [UTIL_VM] # force le mode hôte (IP et utilisateur de la VM demandés si absents)
set -euo pipefail

DEPOT_URL="https://github.com/Milo-gdb/Kubernetes-formation.git"
PAQUETS_VM=(openssh-server curl git vim nano jq bash-completion ca-certificates)
NOMS_INGRESS="task-manager.local api.task-manager.local"
FICHIER_HOSTS="${FICHIER_HOSTS:-/etc/hosts}"

etape()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()     { printf '  \033[32m✔\033[0m %s\n' "$*"; }
info()   { printf '  • %s\n' "$*"; }
alerte() { printf '\033[33m⚠ %s\033[0m\n' "$*" >&2; }
erreur() { printf '\033[31m✘ %s\033[0m\n' "$*" >&2; exit 1; }

MODE=""
ARGS=()
for a in "$@"; do
  case "$a" in
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --vm) MODE=vm ;;
    --hote|--host) MODE=hote ;;
    -*) erreur "Option inconnue : $a (voir --help)" ;;
    *) ARGS+=("$a") ;;
  esac
done

# Utilisateur cible : celui qui a lancé le script, même via sudo.
UTILISATEUR="${SUDO_USER:-$(id -un)}"
HOME_UTILISATEUR="$(getent passwd "$UTILISATEUR" | cut -d: -f6)"
if [ "$(id -u)" -eq 0 ]; then SUDO=(); else SUDO=(sudo); fi
en_utilisateur() {
  if [ "$(id -un)" = "$UTILISATEUR" ]; then "$@"; else sudo -u "$UTILISATEUR" -H "$@"; fi
}

OS_ID=""; OS_ID_LIKE=""; OS_VERSION=""; OS_NOM="inconnu"
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-}"; OS_ID_LIKE="${ID_LIKE:-}"; OS_VERSION="${VERSION_ID:-}"; OS_NOM="${PRETTY_NAME:-$OS_ID}"
fi
est_arch()   { [ "$OS_ID" = "arch" ] || [[ " $OS_ID_LIKE " == *" arch "* ]]; }
est_ubuntu() { [ "$OS_ID" = "ubuntu" ]; }
avec_bureau() { [ "$(systemctl get-default 2>/dev/null)" = "graphical.target" ]; }
virtualise()  { systemd-detect-virt -q --vm 2>/dev/null; }

if [ -z "$MODE" ]; then
  if est_arch; then
    MODE=hote
  elif est_ubuntu && avec_bureau; then
    MODE=hote
  elif est_ubuntu && virtualise; then
    MODE=vm
  else
    erreur "Impossible de deviner le mode sur « $OS_NOM ». Relance avec --vm (dans la VM Ubuntu Server) ou --hote (sur ta machine Ubuntu/Arch)."
  fi
fi

# ---------------------------------------------------------------------------
# Gestionnaires de paquets
# ---------------------------------------------------------------------------
# Sur une machine fraîche, unattended-upgrades tient souvent les verrous apt : on attend qu'il ait fini (10 min max).
attendre_apt() {
  local i=0
  while pgrep -x 'apt|apt-get|dpkg|unattended-upgr' >/dev/null; do
    [ "$i" -eq 0 ] && info "apt/dpkg déjà en cours d'exécution (mises à jour automatiques ?), attente…"
    i=$((i + 5)); [ "$i" -lt 600 ] || break
    sleep 5
  done
}
installer_apt() {
  local apt=("${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=600)
  attendre_apt
  "${apt[@]}" update
  "${apt[@]}" install -y "$@"
}
installer_pacman() {
  # --needed : ne réinstalle pas ce qui est déjà présent. Pas de -Syu : on ne met pas tout le système à jour à ta place.
  "${SUDO[@]}" pacman -S --needed --noconfirm "$@" \
    || erreur "pacman a échoué : mets d'abord le système à jour (sudo pacman -Syu) puis relance le script."
}

ip_principale() {
  local ip
  ip="$(ip -4 route get 1.1.1.1 2>/dev/null | sed -n 's/.* src \([0-9.]*\).*/\1/p' | head -1)"
  [ -n "$ip" ] || ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  echo "${ip:-<IP_VM>}"
}

# ---------------------------------------------------------------------------
# Mode VM : Ubuntu Server
# ---------------------------------------------------------------------------
mode_vm() {
  est_ubuntu || erreur "Le mode VM est prévu pour Ubuntu Server 22.04/24.04 uniquement (système détecté : $OS_NOM). Sur ta machine hôte, utilise --hote."
  case "$OS_VERSION" in
    22.04|24.04) ;;
    *) alerte "Ubuntu $OS_VERSION détecté : script prévu pour 22.04/24.04, on continue quand même." ;;
  esac
  avec_bureau && alerte "Ubuntu avec environnement graphique détecté : la formation prévoit une VM Ubuntu *Server*, on continue quand même."
  virtualise || alerte "Aucune virtualisation détectée : ce mode est prévu pour la VM, on continue quand même."
  [ "$UTILISATEUR" != "root" ] || alerte "Lance ce script avec ton utilisateur habituel (pas root) : le dépôt sera cloné dans son home."

  local dossier="$HOME_UTILISATEUR/Kubernetes-formation"

  etape "Installation des paquets : ${PAQUETS_VM[*]}"
  installer_apt "${PAQUETS_VM[@]}"
  ok "paquets installés"

  etape "Activation du serveur SSH"
  "${SUDO[@]}" systemctl enable --now ssh
  ok "service ssh : $(systemctl is-active ssh)"
  if command -v ufw >/dev/null 2>&1 && "${SUDO[@]}" ufw status | grep -qwE 'active|actif'; then
    "${SUDO[@]}" ufw allow ssh
    ok "pare-feu ufw actif : port 22 ouvert"
  else
    info "ufw inactif ou absent : rien à ouvrir"
  fi

  etape "Dépôt de la formation dans $dossier"
  if [ -d "$dossier/.git" ]; then
    if en_utilisateur git -C "$dossier" pull --ff-only; then
      ok "dépôt déjà présent, mis à jour"
    else
      info "dépôt déjà présent, mise à jour impossible (modifications locales ?) : laissé tel quel"
    fi
  elif [ -e "$dossier" ]; then
    erreur "$dossier existe mais n'est pas un dépôt git : déplace-le puis relance le script."
  else
    en_utilisateur git clone "$DEPOT_URL" "$dossier"
    ok "dépôt cloné"
  fi

  local ip; ip="$(ip_principale)"
  etape "VM prête"
  echo "Adresses réseau (ip a) :"
  ip -brief address show | grep -vE '^(lo|veth|cni|flannel|docker|kube)' | sed 's/^/    /'
  echo
  echo "IP principale de la VM : $ip"
  echo
  echo "Depuis la machine hôte, connecte-toi avec :"
  echo "    ssh $UTILISATEUR@$ip"
  echo
  echo "Rappels :"
  echo "  (a) Sur la machine hôte (Ubuntu ou Arch), lance ce même script en mode hôte :"
  echo "          bash setup-vm.sh --hote $ip $UTILISATEUR"
  echo "      il ajoute « $ip $NOMS_INGRESS » à /etc/hosts pour l'Ingress du fil rouge (chapitre 06)."
  printf '%s\n' "      (Sous Windows, ajoute la ligne à la main dans C:\\Windows\\System32\\drivers\\etc\\hosts.)"
  echo "  (b) Prends un snapshot de la VM MAINTENANT, avant d'installer k3s :"
  echo "      tu pourras ainsi repartir de zéro à tout moment."
  echo
  echo "Ensuite : cd ~/Kubernetes-formation et commence au chapitre 00 (00-prerequis/lecon.md)."
  echo "k3s et kubectl (chapitre 02), Helm (chapitre 12) et k9s (bonus 01) s'installent en suivant les leçons."
}

# ---------------------------------------------------------------------------
# Mode hôte : Ubuntu ou Arch Linux
# ---------------------------------------------------------------------------
demander() {  # demander <invite> <défaut> → lit sur le terminal, même si le script est lu depuis un pipe
  local reponse=""
  if (exec </dev/tty) 2>/dev/null; then
    read -r -p "$1" reponse </dev/tty || true
  fi
  echo "${reponse:-$2}"
}

mettre_a_jour_hosts() {  # remplace toute ligne existante pour les noms du fil rouge, puis ajoute la nouvelle
  local ligne="$1 $NOMS_INGRESS" tmp
  if grep -qxF "$ligne" "$FICHIER_HOSTS"; then
    ok "$FICHIER_HOSTS contient déjà : $ligne"
    return
  fi
  tmp="$(mktemp)"
  grep -vE '(^|[[:space:]])(api\.)?task-manager\.local([[:space:]]|$)' "$FICHIER_HOSTS" >"$tmp" || true
  echo "$ligne" >>"$tmp"
  # Sauvegarde unique : on garde l'état d'avant le tout premier passage du script.
  [ -e "$FICHIER_HOSTS.avant-formation" ] || "${SUDO[@]}" cp "$FICHIER_HOSTS" "$FICHIER_HOSTS.avant-formation"
  # cat + tee plutôt que mv : conserve le fichier, ses droits et fonctionne même s'il est monté (conteneurs).
  "${SUDO[@]}" tee "$FICHIER_HOSTS" <"$tmp" >/dev/null
  rm -f "$tmp"
  ok "$FICHIER_HOSTS mis à jour : $ligne (sauvegarde : $FICHIER_HOSTS.avant-formation)"
}

mode_hote() {
  local ip_vm="${ARGS[0]:-}" util_vm="${ARGS[1]:-}"

  etape "Machine hôte : $OS_NOM"
  local manquants=()
  command -v ssh  >/dev/null 2>&1 || manquants+=(ssh)
  command -v curl >/dev/null 2>&1 || manquants+=(curl)
  command -v git  >/dev/null 2>&1 || manquants+=(git)
  if [ ${#manquants[@]} -eq 0 ]; then
    ok "ssh, curl et git déjà installés"
  elif command -v pacman >/dev/null 2>&1; then
    local paquets=()
    for o in "${manquants[@]}"; do [ "$o" = ssh ] && paquets+=(openssh) || paquets+=("$o"); done
    installer_pacman "${paquets[@]}"
    ok "installés avec pacman : ${paquets[*]}"
  elif command -v apt-get >/dev/null 2>&1; then
    local paquets=()
    for o in "${manquants[@]}"; do [ "$o" = ssh ] && paquets+=(openssh-client) || paquets+=("$o"); done
    installer_apt "${paquets[@]}"
    ok "installés avec apt : ${paquets[*]}"
  else
    erreur "Ni pacman ni apt trouvés : installe toi-même ${manquants[*]} puis relance le script."
  fi

  etape "Adresse de la VM"
  [ -n "$ip_vm" ] || ip_vm="$(demander "IP de la VM (affichée à la fin du script dans la VM) : " "")"
  [[ "$ip_vm" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] \
    || erreur "IP de VM invalide : « $ip_vm ». Exemple : bash setup-vm.sh --hote 192.168.1.42 $UTILISATEUR"
  [ -n "$util_vm" ] || util_vm="$(demander "Utilisateur de la VM [$UTILISATEUR] : " "$UTILISATEUR")"
  ok "VM : $util_vm@$ip_vm"

  etape "Résolution de $NOMS_INGRESS (Ingress du chapitre 06)"
  mettre_a_jour_hosts "$ip_vm"

  etape "Test de la connexion SSH vers la VM"
  if timeout 5 bash -c "exec 3<>/dev/tcp/$ip_vm/22" 2>/dev/null; then
    ok "port 22 joignable sur $ip_vm"
  else
    alerte "Port 22 injoignable sur $ip_vm : vérifie que la VM tourne, que sa carte réseau est en mode pont (bridge) et que setup-vm.sh y a été lancé."
  fi

  etape "Hôte prêt"
  echo "Connecte-toi à la VM avec :"
  echo "    ssh $util_vm@$ip_vm"
  echo
  echo "Astuce : pour ne plus taper le mot de passe, crée une clé (ssh-keygen -t ed25519) puis copie-la :"
  echo "    ssh-copy-id $util_vm@$ip_vm"
  echo
  echo "Au chapitre 06, http://task-manager.local et http://api.task-manager.local répondront depuis ce navigateur."
}

case "$MODE" in
  vm) mode_vm ;;
  hote) mode_hote ;;
esac
