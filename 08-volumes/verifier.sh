#!/usr/bin/env bash
# Vérification du TD 08 — Volumes
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/lib.sh"
NS=td-08

titre "TD 08 — Volumes"
exiger_cluster

ex1() { pod_running $NS ephemere && exec_contient $NS ephemere "20" -- cat /data/date.txt; }
exercice "Ex.1 — Pod ephemere en Running avec /data/date.txt" \
  "Le Pod doit créer le répertoire puis écrire la date avant de dormir." ex1

ex2() { pvc_bound $NS donnees && [ "$(kget $NS pvc/donnees '{.spec.resources.requests.storage}')" = 200Mi ] \
  && [ "$(kget $NS pvc/donnees '{.spec.storageClassName}')" = local-path ] && deploy_pret $NS ecrivain 1 \
  && [ "$(kget $NS deploy/ecrivain '{.spec.template.spec.volumes[*].persistentVolumeClaim.claimName}')" = donnees ]; }
exercice "Ex.2 — PVC donnees (200Mi, local-path) liée et montée par le Deployment ecrivain" \
  "Une PVC local-path reste Pending tant qu'aucun Pod ne la monte ; vérifie claimName." ex2

pod_ecrivain() { $KUBECTL get pods -n $NS -l app=ecrivain -o jsonpath='{.items[0].metadata.name}' 2>/dev/null; }
ex3() { local p; p=$(pod_ecrivain); [ -n "$p" ] && exec_contient $NS "$p" "persistant" -- cat /data/preuve.txt \
  && [ "$($KUBECTL exec -n $NS "$p" -- sh -c 'wc -l < /data/journal.txt' 2>/dev/null)" -gt 3 ]; }
exercice "Ex.3 — /data/preuve.txt contient « persistant » et le journal a survécu" \
  "Le fichier doit être écrit dans le point de montage du volume, pas ailleurs dans le conteneur." ex3

ex4() { [ "$($KUBECTL get pv pv-manuel -o jsonpath='{.spec.persistentVolumeReclaimPolicy}' 2>/dev/null)" = Retain ] \
  && pvc_bound $NS pvc-manuelle && [ "$(kget $NS pvc/pvc-manuelle '{.spec.volumeName}')" = pv-manuel ]; }
exercice "Ex.4 — PV pv-manuel (Retain) lié à la PVC pvc-manuelle" \
  "PV et PVC doivent partager la même storageClassName et des modes d'accès / tailles compatibles." ex4

ex5a() { pvc_bound task-manager postgres-data && deploy_pret task-manager postgres 1 \
  && [ "$(kget task-manager deploy/postgres '{.spec.strategy.type}')" = Recreate ] \
  && kget task-manager deploy/postgres '{.spec.template.spec.volumes[*].persistentVolumeClaim.claimName}' | grep -qw postgres-data; }
exercice "Ex.5a — Fil rouge : PostgreSQL monte la PVC postgres-data (stratégie Recreate)" \
  "Applique fil-rouge/08-volumes/ ; le Deployment doit référencer la PVC et ne pas faire de rolling update." ex5a

ex5b() { local pod; pod=$($KUBECTL get pods -n task-manager -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  [ -n "$pod" ] && $KUBECTL exec -n task-manager "$pod" -- sh -c 'echo $PGDATA' 2>/dev/null | grep -q '^/var/lib/postgresql/data/'; }
exercice "Ex.5b — Fil rouge : les données PostgreSQL (PGDATA) sont sur le volume" \
  "PGDATA doit pointer dans un sous-répertoire du point de montage de la PVC." ex5b

bilan
