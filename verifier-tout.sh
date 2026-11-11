#!/usr/bin/env bash
# Lance les verifier.sh de tous les chapitres (ou de ceux passés en argument) et affiche un récapitulatif.
# Usage : ./verifier-tout.sh            # tout
#         ./verifier-tout.sh 03 05 b01  # certains chapitres (préfixes de dossiers)
#         ./verifier-tout.sh -q         # n'affiche que le récapitulatif
RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CALME=0
FILTRES=()
for a in "$@"; do
  case "$a" in
    -q|--quiet) CALME=1 ;;
    -h|--help) sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    b0*) FILTRES+=("bonus-0${a#b0}") ;;
    *) FILTRES+=("$a") ;;
  esac
done

dossiers=()
for d in "$RACINE"/[0-9][0-9]-*/ "$RACINE"/bonus-*/; do
  d="$(basename "$d")"
  [ -x "$RACINE/$d/verifier.sh" ] || continue
  if [ ${#FILTRES[@]} -gt 0 ]; then
    garde=0
    for f in "${FILTRES[@]}"; do [[ "$d" == "$f"* ]] && garde=1; done
    [ "$garde" -eq 1 ] || continue
  fi
  dossiers+=("$d")
done

[ ${#dossiers[@]} -gt 0 ] || { echo "Aucun chapitre ne correspond à : ${FILTRES[*]}"; exit 2; }

declare -a lignes
ok_total=0
for d in "${dossiers[@]}"; do
  sortie="$("$RACINE/$d/verifier.sh" 2>&1)"
  code=$?
  [ "$CALME" -eq 1 ] || echo "$sortie"
  score="$(echo "$sortie" | sed -n 's/.*Bilan : \([0-9]*\/[0-9]*\).*/\1/p' | tail -1)"
  case $code in
    0) etat="✅"; ok_total=$((ok_total + 1)) ;;
    2) etat="⛔"; score="cluster injoignable" ;;
    *) etat="❌" ;;
  esac
  lignes+=("$(printf '  %s %-34s %s' "$etat" "$d" "${score:-?}")")
done

echo
echo "=== Récapitulatif ==="
printf '%s\n' "${lignes[@]}"
echo
echo "Chapitres entièrement validés : ${ok_total}/${#dossiers[@]}"
[ "$ok_total" -eq ${#dossiers[@]} ]
