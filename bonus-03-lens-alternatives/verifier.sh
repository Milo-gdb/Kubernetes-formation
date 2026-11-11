#!/usr/bin/env bash
# Vérification du TD bonus 03 — Interfaces graphiques
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/lib.sh"
DOSSIER="${HOME}/formation-k8s/bonus03"
K="$DOSSIER/kubeconfig-gui"

titre "TD bonus 03 — Lens et alternatives"

choix() { local f="$DOSSIER/choix.md"; [ -s "$f" ] && grep -qi freelens "$f" && grep -qi headlamp "$f" \
  && grep -qi openlens "$f" && grep -qiE "propriétaire|freemium" "$f" && grep -qiE "MIT|Apache" "$f"; }
exercice "Ex.1 — Enquête rédigée (licences de Lens, OpenLens, Freelens, Headlamp…)" \
  "choix.md doit citer chaque outil demandé avec sa licence et son modèle (libre ou non)." choix

exiger_cluster

exercice "Ex.2a — ServiceAccount gui-lecture en lecture seule" \
  "Un ClusterRole prédéfini donne la lecture sans les Secrets ; lie-le au compte à l'échelle du cluster." \
  bash -c '[ "$('"$KUBECTL"' auth can-i list deployments -A --as=system:serviceaccount:kube-system:gui-lecture)" = yes ] &&
           [ "$('"$KUBECTL"' auth can-i delete pods -A --as=system:serviceaccount:kube-system:gui-lecture)" = no ]'

kubeconfig_ok() { [ -f "$K" ] && [ "$(stat -c %a "$K")" = 600 ] \
  && [ "$($KUBECTL --kubeconfig "$K" config current-context 2>/dev/null)" = formation-lecture ] \
  && $KUBECTL --kubeconfig "$K" config view --minify -o jsonpath='{.users[0].user.token}' 2>/dev/null | grep -q . ; }
exercice "Ex.2b — kubeconfig-gui valide (contexte formation-lecture, jeton, droits 600)" \
  "Le fichier doit contenir cluster, utilisateur à jeton et contexte courant, et n'être lisible que par toi." kubeconfig_ok

kubeconfig_droits() { local KUBECTL="$KUBECTL --kubeconfig $K"; $KUBECTL get pods -n task-manager >/dev/null 2>&1 \
  && [ "$($KUBECTL auth can-i delete pods -n task-manager 2>/dev/null)" = no ] \
  && ! $KUBECTL get secrets -n task-manager >/dev/null 2>&1; }
exercice "Ex.2c — kubeconfig-gui : lecture des Pods du fil rouge, ni suppression ni Secrets" \
  "Teste ton fichier avec kubectl --kubeconfig ; un jeton expiré se régénère." kubeconfig_droits

if commande_existe freelens || ls /opt/Freelens* >/dev/null 2>&1; then info "Freelens est installé sur ce poste."
else info "Freelens non détecté (normal sur une machine sans interface graphique, Ex.3 non vérifié)."; fi

bilan
