#!/usr/bin/env bash
# Prépare une VM Ubuntu Server 22.04/24.04 fraîche pour suivre la formation Kubernetes.
# Installe et active SSH, quelques paquets de base, puis clone le dépôt dans le home de l'utilisateur.
# N'installe volontairement NI k3s, NI kubectl (chapitre 02), NI Helm (chapitre 12), NI k9s (bonus 01).
# Idempotent : peut être relancé sans risque.
# Usage : bash setup-vm.sh   (en utilisateur normal disposant de sudo)
set -euo pipefail

DEPOT_URL="https://github.com/Milo-gdb/Kubernetes-formation.git"
PAQUETS=(openssh-server curl git vim nano jq bash-completion ca-certificates)

case "${1:-}" in
  -h|--help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

etape() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()    { printf '  \033[32m✔\033[0m %s\n' "$*"; }
info()  { printf '  • %s\n' "$*"; }

# Utilisateur cible : celui qui a lancé le script, même via sudo.
UTILISATEUR="${SUDO_USER:-$(id -un)}"
if [ "$UTILISATEUR" = "root" ]; then
  echo "⚠ Lance ce script avec ton utilisateur habituel (pas root) : le dépôt sera cloné dans son home." >&2
fi
HOME_UTILISATEUR="$(getent passwd "$UTILISATEUR" | cut -d: -f6)"
DOSSIER_DEPOT="$HOME_UTILISATEUR/Kubernetes-formation"

if [ "$(id -u)" -eq 0 ]; then SUDO=(); else SUDO=(sudo); fi
en_utilisateur() {
  if [ "$(id -un)" = "$UTILISATEUR" ]; then "$@"; else sudo -u "$UTILISATEUR" -H "$@"; fi
}

if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-}:${VERSION_ID:-}" in
    ubuntu:22.04|ubuntu:24.04) ;;
    *) echo "⚠ Système détecté : ${PRETTY_NAME:-inconnu}. Script prévu pour Ubuntu Server 22.04/24.04, on continue quand même." >&2 ;;
  esac
fi

# 1. SSH + 2. paquets de base
etape "Installation des paquets : ${PAQUETS[*]}"
# Sur une VM fraîche, unattended-upgrades tient souvent les verrous apt : on attend qu'il ait fini (10 min max).
attendre_apt() {
  local i=0
  while pgrep -x 'apt|apt-get|dpkg|unattended-upgr' >/dev/null; do
    [ "$i" -eq 0 ] && info "apt/dpkg déjà en cours d'exécution (mises à jour automatiques ?), attente…"
    i=$((i + 5)); [ "$i" -lt 600 ] || break
    sleep 5
  done
}
APT=("${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=600)
attendre_apt
"${APT[@]}" update
"${APT[@]}" install -y "${PAQUETS[@]}"
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

# 3. Dépôt de la formation
etape "Dépôt de la formation dans $DOSSIER_DEPOT"
if [ -d "$DOSSIER_DEPOT/.git" ]; then
  if en_utilisateur git -C "$DOSSIER_DEPOT" pull --ff-only; then
    ok "dépôt déjà présent, mis à jour"
  else
    info "dépôt déjà présent, mise à jour impossible (modifications locales ?) : laissé tel quel"
  fi
elif [ -e "$DOSSIER_DEPOT" ]; then
  echo "✘ $DOSSIER_DEPOT existe mais n'est pas un dépôt git : déplace-le puis relance le script." >&2
  exit 1
else
  en_utilisateur git clone "$DEPOT_URL" "$DOSSIER_DEPOT"
  ok "dépôt cloné"
fi

# 4. Résumé
IP="$(ip -4 route get 1.1.1.1 2>/dev/null | sed -n 's/.* src \([0-9.]*\).*/\1/p' | head -1)"
[ -n "$IP" ] || IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
IP="${IP:-<IP_VM>}"

etape "VM prête"
echo "Adresses réseau (ip a) :"
ip -brief address show | grep -vE '^(lo|veth|cni|flannel|docker|kube)' | sed 's/^/    /'
echo
echo "IP principale de la VM : $IP"
echo
echo "Depuis la machine hôte, connecte-toi avec :"
echo "    ssh $UTILISATEUR@$IP"
echo
echo "Rappels :"
echo "  (a) Sur la machine hôte, ajoute cette ligne au fichier /etc/hosts"
printf '%s\n' "      (C:\\Windows\\System32\\drivers\\etc\\hosts sous Windows) pour l'Ingress du fil rouge (chapitre 06) :"
echo "          $IP task-manager.local api.task-manager.local"
echo "  (b) Prends un snapshot de la VM MAINTENANT, avant d'installer k3s :"
echo "      tu pourras ainsi repartir de zéro à tout moment."
echo
echo "Ensuite : cd ~/Kubernetes-formation et commence au chapitre 00 (00-prerequis/lecon.md)."
echo "k3s et kubectl (chapitre 02), Helm (chapitre 12) et k9s (bonus 01) s'installent en suivant les leçons."
