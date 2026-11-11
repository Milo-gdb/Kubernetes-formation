#!/usr/bin/env bash
# Prépare l'environnement de la formation Kubernetes. Trois modes :
#   VM      (Ubuntu Server 22.04/24.04) : SSH, paquets de base, clone du dépôt, résumé (IP, ssh, snapshot).
#   hôte    (Ubuntu ou Arch Linux)      : client SSH, entrée task-manager.local dans /etc/hosts, test de la VM.
#   complet (Ubuntu ou Arch Linux)      : crée en plus la VM Ubuntu Server (KVM/libvirt) et la configure entièrement.
# Le mode VM ou hôte est détecté automatiquement (Arch ou Ubuntu avec bureau → hôte, Ubuntu Server virtualisé → VM).
# N'installe volontairement NI k3s, NI kubectl (chapitre 02), NI Helm (chapitre 12), NI k9s (bonus 01).
# Idempotent : peut être relancé sans risque.
# Usage : bash setup-vm.sh                          # mode détecté automatiquement
#         bash setup-vm.sh --vm                     # force le mode VM
#         bash setup-vm.sh --hote [IP_VM] [UTIL_VM] # force le mode hôte (IP et utilisateur de la VM demandés si absents)
#         bash setup-vm.sh --complet                # crée, configure et relie la VM depuis l'hôte
# Variables du mode complet : VM_NOM (formation-k8s), VM_CPU (2), VM_RAM_MO (4096), VM_DISQUE_GO (20),
#         UBUNTU_VERSION (24.04 ou 22.04), IMAGE_URL (image cloud Ubuntu à utiliser à la place de l'officielle).
set -euo pipefail

DEPOT_URL="https://github.com/Milo-gdb/Kubernetes-formation.git"
PAQUETS_VM=(openssh-server curl git vim nano jq bash-completion ca-certificates)
NOMS_INGRESS="task-manager.local api.task-manager.local"
FICHIER_HOSTS="${FICHIER_HOSTS:-/etc/hosts}"
SCRIPT_URL="https://raw.githubusercontent.com/Milo-gdb/Kubernetes-formation/main/setup/setup-vm.sh"
VM_NOM="${VM_NOM:-formation-k8s}"
VM_CPU="${VM_CPU:-2}"
VM_RAM_MO="${VM_RAM_MO:-4096}"
VM_DISQUE_GO="${VM_DISQUE_GO:-20}"
UBUNTU_VERSION="${UBUNTU_VERSION:-24.04}"
SNAPSHOT="avant-k3s"

etape()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()     { printf '  \033[32m✔\033[0m %s\n' "$*"; }
info()   { printf '  • %s\n' "$*"; }
alerte() { printf '\033[33m⚠ %s\033[0m\n' "$*" >&2; }
erreur() { printf '\033[31m✘ %s\033[0m\n' "$*" >&2; exit 1; }

MODE=""
ARGS=()
for a in "$@"; do
  case "$a" in
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --vm) MODE=vm ;;
    --hote|--host) MODE=hote ;;
    --complet|--full) MODE=complet ;;
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
avec_bureau() { compgen -G '/usr/share/xsessions/*.desktop' >/dev/null || compgen -G '/usr/share/wayland-sessions/*.desktop' >/dev/null; }
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
  # unattended-upgrade-shutdown tourne en permanence : on ne cible que le vrai unattended-upgrade.
  while pgrep -x 'apt|apt-get|dpkg' >/dev/null || pgrep -f '/usr/bin/unattended-upgrade( |$)' >/dev/null; do
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

installer_hote() {  # installer_hote "<paquets Arch>" "<paquets Ubuntu>"
  local -a arch deb
  read -r -a arch <<<"$1"
  read -r -a deb <<<"$2"
  if command -v pacman >/dev/null 2>&1; then
    installer_pacman "${arch[@]}"
    ok "paquets présents (pacman) : ${arch[*]}"
  elif command -v apt-get >/dev/null 2>&1; then
    installer_apt "${deb[@]}"
    ok "paquets présents (apt) : ${deb[*]}"
  else
    erreur "Ni pacman ni apt trouvés : installe toi-même ${deb[*]} puis relance le script."
  fi
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

mettre_a_jour_hosts() {  # retire les noms du fil rouge des lignes existantes (autres alias conservés), puis ajoute la nouvelle
  local ligne="$1 $NOMS_INGRESS" tmp
  tmp="$(mktemp)"
  awk '
    { contenu = $0; commentaire = ""; i = index(contenu, "#")
      if (i) { commentaire = substr(contenu, i); contenu = substr(contenu, 1, i - 1) }
      n = split(contenu, champs, " ")
      if (n < 2) { print; next }
      garde = champs[1]; restants = 0; retire = 0
      for (j = 2; j <= n; j++) {
        if (champs[j] == "task-manager.local" || champs[j] == "api.task-manager.local") retire = 1
        else { garde = garde " " champs[j]; restants++ }
      }
      if (!retire) { print; next }
      if (restants > 0) print garde (commentaire != "" ? " " commentaire : "")
    }' "$FICHIER_HOSTS" >"$tmp"
  echo "$ligne" >>"$tmp"
  if cmp -s "$tmp" "$FICHIER_HOSTS"; then
    rm -f "$tmp"
    ok "$FICHIER_HOSTS contient déjà : $ligne"
    return
  fi
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
  else
    local arch=() deb=()
    for o in "${manquants[@]}"; do
      case "$o" in
        ssh) arch+=(openssh); deb+=(openssh-client) ;;
        *) arch+=("$o"); deb+=("$o") ;;
      esac
    done
    installer_hote "${arch[*]}" "${deb[*]}"
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

# ---------------------------------------------------------------------------
# Mode complet : création de la VM depuis l'hôte (KVM/libvirt + image cloud Ubuntu Server minimal)
# ---------------------------------------------------------------------------
VIRSH=("${SUDO[@]}" virsh -c qemu:///system)
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5 -o BatchMode=yes)

ip_de_la_vm() {
  "${VIRSH[@]}" domifaddr "$VM_NOM" --source lease 2>/dev/null \
    | awk '$3 == "ipv4" { split($4, a, "/"); print a[1]; exit }'
}

ssh_vm() {  # ssh_vm <ip> <commande…> : avec la clé de l'utilisateur, sans polluer son known_hosts
  local ip="$1"; shift
  en_utilisateur ssh "${SSH_OPTS[@]}" "$UTILISATEUR@$ip" "$@"
}

cle_ssh_publique() {  # affiche le chemin de la clé publique de l'utilisateur, en crée une si besoin
  local c
  for c in id_ed25519 id_ecdsa id_rsa; do
    [ -r "$HOME_UTILISATEUR/.ssh/$c.pub" ] && { echo "$HOME_UTILISATEUR/.ssh/$c.pub"; return; }
  done
  en_utilisateur mkdir -p -m 700 "$HOME_UTILISATEUR/.ssh"
  en_utilisateur ssh-keygen -q -t ed25519 -N "" -C "$UTILISATEUR@formation-k8s" -f "$HOME_UTILISATEUR/.ssh/id_ed25519"
  echo "$HOME_UTILISATEUR/.ssh/id_ed25519.pub"
}

ecrire_user_data() {  # ecrire_user_data <fichier> <clé publique> : cloud-init qui crée l'utilisateur et lance le mode VM
  local fichier="$1" cle script_b64 source_script="$0" tmp_script=""
  cle="$(cat "$2")"
  if [ ! -f "$source_script" ]; then  # script lu depuis un pipe : on récupère la version publiée
    tmp_script="$(mktemp)"; curl -fsSL "$SCRIPT_URL" -o "$tmp_script"; source_script="$tmp_script"
  fi
  script_b64="$(base64 -w0 "$source_script")"
  [ -z "$tmp_script" ] || rm -f "$tmp_script"
  cat >"$fichier" <<CLOUDINIT
#cloud-config
hostname: $VM_NOM
users:
  - name: $UTILISATEUR
    groups: [sudo]
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: true
    ssh_authorized_keys:
      - "$cle"
write_files:
  - path: /usr/local/sbin/setup-vm.sh
    permissions: "0755"
    encoding: b64
    content: $script_b64
runcmd:
  - [su, "-", "$UTILISATEUR", "-c", "bash /usr/local/sbin/setup-vm.sh --vm"]
CLOUDINIT
}

attendre() {  # attendre <secondes> <message> <commande…> : réessaie la commande toutes les 3 s
  local max="$1" msg="$2" t=0; shift 2
  until "$@" >/dev/null 2>&1; do
    t=$((t + 3)); [ "$t" -lt "$max" ] || erreur "$msg"
    sleep 3
  done
}

mode_complet() {
  est_arch || est_ubuntu || erreur "Le mode complet est prévu pour un hôte Ubuntu ou Arch Linux (système détecté : $OS_NOM)."
  [ "$UTILISATEUR" != "root" ] || erreur "Lance le mode complet avec ton utilisateur habituel (pas root) : il devient l'utilisateur de la VM."
  [ -e /dev/kvm ] || erreur "/dev/kvm absent : active la virtualisation (Intel VT-x / AMD-V) dans le BIOS/UEFI, puis relance."
  local code
  case "$UBUNTU_VERSION" in
    24.04) code=noble ;;
    22.04) code=jammy ;;
    *) erreur "UBUNTU_VERSION=$UBUNTU_VERSION non prise en charge (24.04 ou 22.04)." ;;
  esac
  local image_url="${IMAGE_URL:-https://cloud-images.ubuntu.com/minimal/releases/$code/release/ubuntu-$UBUNTU_VERSION-minimal-cloudimg-amd64.img}"
  local dossier=/var/lib/libvirt/images
  local image disque="$dossier/$VM_NOM.qcow2"
  image="$dossier/$(basename "$image_url")"

  etape "Virtualisation sur l'hôte ($OS_NOM) : KVM + libvirt"
  installer_hote "qemu-base libvirt virt-install dnsmasq nftables libisoburn openssh curl git" \
                 "qemu-system-x86 qemu-utils libvirt-daemon-system libvirt-clients virtinst xorriso openssh-client curl git"
  "${SUDO[@]}" systemctl enable --now libvirtd
  ok "libvirtd : $(systemctl is-active libvirtd)"
  if ! id -nG "$UTILISATEUR" | grep -qw libvirt; then
    "${SUDO[@]}" usermod -aG libvirt "$UTILISATEUR"
    info "$UTILISATEUR ajouté au groupe libvirt (virt-manager sans sudo après reconnexion)"
  fi
  if ! "${VIRSH[@]}" net-info default >/dev/null 2>&1; then
    "${VIRSH[@]}" net-define /usr/share/libvirt/networks/default.xml >/dev/null
  fi
  "${VIRSH[@]}" net-info default | grep -qE '^Active:\s+yes' || "${VIRSH[@]}" net-start default >/dev/null
  "${VIRSH[@]}" net-autostart default >/dev/null
  ok "réseau libvirt « default » (NAT) actif"

  local vm_creee=""
  etape "VM $VM_NOM : Ubuntu Server $UBUNTU_VERSION minimal, $VM_CPU vCPU, $VM_RAM_MO Mo de RAM, $VM_DISQUE_GO Go de disque"
  if "${VIRSH[@]}" dominfo "$VM_NOM" >/dev/null 2>&1; then
    ok "VM déjà existante : on la réutilise"
    "${VIRSH[@]}" domstate "$VM_NOM" | grep -q running || { "${VIRSH[@]}" start "$VM_NOM" >/dev/null; ok "VM démarrée"; }
  else
    local cle user_data
    cle="$(cle_ssh_publique)"
    ok "clé SSH : $cle"
    if [ -s "$image" ]; then
      ok "image déjà téléchargée : $image"
    else
      info "téléchargement de $image_url"
      "${SUDO[@]}" curl -fL --retry 3 --progress-bar -o "$image.part" "$image_url"
      "${SUDO[@]}" mv "$image.part" "$image"
      ok "image téléchargée : $image"
    fi
    if [ ! -e "$disque" ]; then
      "${SUDO[@]}" cp "$image" "$disque"
      "${SUDO[@]}" qemu-img resize -q "$disque" "${VM_DISQUE_GO}G"
    fi
    ok "disque : $disque"
    user_data="$(mktemp)"
    ecrire_user_data "$user_data" "$cle"
    local osinfo="detect=on,require=off" liste
    liste="$(virt-install --osinfo list 2>/dev/null || true)"
    if grep -qE "^ubuntu$UBUNTU_VERSION(,|$)" <<<"$liste"; then osinfo="ubuntu$UBUNTU_VERSION"
    elif grep -qE "^linux2022(,|$)" <<<"$liste"; then osinfo="linux2022"
    fi
    "${SUDO[@]}" virt-install --connect qemu:///system --name "$VM_NOM" \
      --memory "$VM_RAM_MO" --vcpus "$VM_CPU" \
      --disk "path=$disque,format=qcow2,bus=virtio" --import --osinfo "$osinfo" \
      --network network=default,model=virtio --graphics none --noautoconsole \
      --cloud-init "user-data=$user_data"
    rm -f "$user_data"
    vm_creee=1
    ok "VM créée et démarrée"
  fi

  etape "Configuration de la VM (cloud-init puis setup-vm.sh --vm, quelques minutes)"
  local ip=""
  attendre 300 "La VM n'a pas obtenu d'IP au bout de 5 min (sudo virsh console $VM_NOM pour voir son démarrage)." \
    bash -c "[ -n \"\$(\"\$@\" domifaddr '$VM_NOM' --source lease 2>/dev/null | awk '\$3 == \"ipv4\"')\" ]" _ "${VIRSH[@]}"
  ip="$(ip_de_la_vm)"
  ok "IP de la VM : $ip"
  attendre 300 "SSH ne répond pas sur $ip au bout de 5 min." ssh_vm "$ip" true
  ok "SSH opérationnel"
  info "attente de la fin de cloud-init et de setup-vm.sh dans la VM…"
  ssh_vm "$ip" cloud-init status --wait >/dev/null || true
  if ! ssh_vm "$ip" test -d Kubernetes-formation/.git; then
    alerte "Le dépôt n'est pas cloné dans la VM : nouvel essai de setup-vm.sh --vm (journal : /var/log/cloud-init-output.log)."
    ssh_vm "$ip" bash /usr/local/sbin/setup-vm.sh --vm
  fi
  ok "VM configurée (SSH, paquets de base, dépôt cloné dans ~/Kubernetes-formation)"
  # VM neuve = nouvelle clé d'hôte : on oublie seulement l'ancienne clé connue pour cette IP.
  [ -z "$vm_creee" ] || en_utilisateur ssh-keygen -R "$ip" >/dev/null 2>&1 || true

  etape "Résolution de $NOMS_INGRESS (Ingress du chapitre 06)"
  mettre_a_jour_hosts "$ip"

  etape "Snapshot « $SNAPSHOT »"
  if "${VIRSH[@]}" snapshot-info "$VM_NOM" "$SNAPSHOT" >/dev/null 2>&1; then
    ok "snapshot déjà présent"
  else
    if ssh_vm "$ip" command -v k3s >/dev/null 2>&1; then
      alerte "k3s est déjà installé dans la VM : pas de snapshot « $SNAPSHOT » (il ne serait plus « avant k3s »)."
    else
      "${VIRSH[@]}" snapshot-create-as "$VM_NOM" "$SNAPSHOT" "VM préparée par setup-vm.sh, avant l'installation de k3s" >/dev/null
      ok "snapshot créé"
    fi
  fi

  etape "Tout est prêt"
  echo "Connecte-toi à la VM avec :"
  echo "    ssh $UTILISATEUR@$ip"
  echo "puis commence au chapitre 00 (00-prerequis/lecon.md) dans ~/Kubernetes-formation."
  echo
  echo "Gestion de la VM (depuis l'hôte) :"
  echo "    sudo virsh shutdown $VM_NOM                       # éteindre"
  echo "    sudo virsh start $VM_NOM                          # rallumer (l'IP reste la même)"
  echo "    sudo virsh snapshot-revert $VM_NOM $SNAPSHOT      # repartir de zéro, avant k3s"
  echo "    sudo virsh destroy $VM_NOM; sudo virsh undefine $VM_NOM --remove-all-storage --snapshots-metadata   # supprimer"
  echo
  echo "k3s et kubectl (chapitre 02), Helm (chapitre 12) et k9s (bonus 01) s'installent en suivant les leçons."
}

# Bloc lu en entier avant exécution, puis exit : le script reste sûr même si le fichier change pendant qu'il tourne.
{
  case "$MODE" in
    vm) mode_vm ;;
    hote) mode_hote ;;
    complet) mode_complet ;;
  esac
  exit
}
