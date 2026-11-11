#!/usr/bin/env bash
# Vérification du TD 04 — Deployments
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/lib.sh"
NS=td-04

titre "TD 04 — Deployments"
exiger_cluster

exercice "Ex.1 — Deployment web créé dans td-04 (sélecteur app=web)" \
  "kind: Deployment, apiVersion apps/v1, et un selector.matchLabels identique aux labels du template." \
  bash -c "[ \"\$($KUBECTL get deploy web -n $NS -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null)\" = web ]"

ex2() { replicas_egal $NS deployment/web 5 && deploy_pret $NS web 5; }
exercice "Ex.2 — web : 5 réplicas demandés et prêts" \
  "Modifie le champ replicas puis réapplique ; vérifie avec kubectl get deploy." ex2

ex3() { image_contient $NS deployment/web "nginx:1.30-alpine" && deploy_pret $NS web; }
exercice "Ex.3 — web utilise nginx:1.30-alpine et tous ses Pods sont prêts" \
  "Change l'image du conteneur nginx puis suis kubectl rollout status." ex3

ex4() {
  local rev nonprets
  rev=$(kget $NS deployment/web '{.metadata.annotations.deployment\.kubernetes\.io/revision}')
  nonprets=$($KUBECTL get pods -n $NS -l app=web --no-headers 2>/dev/null | grep -cv Running)
  [ "${rev:-0}" -ge 4 ] && image_contient $NS deployment/web "nginx:1.30-alpine" && [ "$nonprets" -eq 0 ] && deploy_pret $NS web 5
}
exercice "Ex.4 — Rollback effectué (≥ 4 révisions, retour à 1.30, aucun Pod en erreur)" \
  "Passe par l'image inexistante, puis utilise une sous-commande de 'kubectl rollout' pour annuler." ex4

ex5() {
  ! ressource_existe task-manager pod frontend \
    && deploy_pret task-manager frontend 3 && deploy_pret task-manager api 2 && deploy_pret task-manager postgres 1
}
exercice "Ex.5 — Fil rouge : Deployments frontend (3), api (2) et postgres (1) prêts, Pod nu supprimé" \
  "Compare tes manifestes à la leçon : noms, réplicas, images. Le Pod frontend du ch.03 doit être supprimé." ex5

bilan
