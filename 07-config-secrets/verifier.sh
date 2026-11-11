#!/usr/bin/env bash
# Vérification du TD 07 — ConfigMaps et Secrets
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/lib.sh"
NS=td-07

titre "TD 07 — ConfigMaps et Secrets"
exiger_cluster

ex1() { valeur_configmap $NS parametres COULEUR bleu && valeur_configmap $NS parametres TAILLE 42 \
  && pod_running $NS lecteur-env && exec_contient $NS lecteur-env "COULEUR=bleu" -- env; }
exercice "Ex.1 — ConfigMap parametres injecté dans lecteur-env" \
  "Une seule directive permet d'importer toutes les clés d'un ConfigMap comme variables." ex1

ex2() { cle_presente $NS configmap fichiers message.txt && pod_running $NS lecteur-vol \
  && exec_contient $NS lecteur-vol "mis à jour" -- cat /config/message.txt; }
exercice "Ex.2 — ConfigMap fichiers monté dans /config et mis à jour" \
  "La clé doit s'appeler message.txt ; le volume se met à jour seul, attends un peu après la modification." ex2

ex3() { cle_presente $NS secret identifiants motdepasse && cle_presente $NS secret identifiants utilisateur \
  && pod_running $NS lecteur-secret \
  && exec_contient $NS lecteur-secret "Formation-K8s" -- sh -c 'echo $DB_PASSWORD' \
  && exec_contient $NS lecteur-secret "Formation-K8s" -- cat /secrets/motdepasse; }
exercice "Ex.3 — Secret identifiants exposé en variable DB_PASSWORD et monté dans /secrets" \
  "Il faut à la fois un env avec secretKeyRef et un volume de type secret." ex3

ex4() { [ "$(kget $NS configmap/version '{.immutable}')" = true ] && valeur_configmap $NS version NUMERO 1; }
exercice "Ex.4 — ConfigMap version immuable" \
  "Un champ au premier niveau de l'objet (à côté de data) rend un ConfigMap non modifiable." ex4

ex5a() {
  for s in postgres-credentials api-db; do ressource_existe task-manager secret $s || return 1; done
  for c in api-config postgres-init frontend-nginx frontend-html; do ressource_existe task-manager configmap $c || return 1; done
  cle_presente task-manager secret postgres-credentials POSTGRES_PASSWORD && cle_presente task-manager secret api-db PGRST_DB_URI
}
exercice "Ex.5a — Fil rouge : Secrets et ConfigMaps du task-manager présents" \
  "Compare la liste des objets attendus dans la leçon (section 6) avec kubectl get cm,secret -n task-manager." ex5a

ex5b() { ! $KUBECTL get deploy -n task-manager -o yaml 2>/dev/null | grep -qiE 'value: .*(ChangeMe|postgres://)'; }
exercice "Ex.5b — Fil rouge : aucun mot de passe en clair dans les Deployments" \
  "Les variables sensibles doivent venir de secretKeyRef / secretRef, pas d'un champ value." ex5b

ex5c() { deploy_pret task-manager api && http_port_forward task-manager svc/frontend 80 /api/tasks '"title"'; }
exercice "Ex.5c — Fil rouge : le frontend relaie /api/tasks vers l'API qui lit la base" \
  "Si /api/tasks échoue : journaux de l'API, puis de PostgreSQL (init.sql exécuté ? rôle web_anon créé ?)." ex5c

bilan
