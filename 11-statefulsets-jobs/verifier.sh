#!/usr/bin/env bash
# Vérification du TD 11 — StatefulSets, DaemonSets, Jobs et CronJobs
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/lib.sh"
NS=td-11

titre "TD 11 — StatefulSets, DaemonSets, Jobs et CronJobs"
exiger_cluster

ex1() { [ "$(kget $NS svc/web '{.spec.clusterIP}')" = None ] && [ "$(kget $NS sts/web '{.status.readyReplicas}')" = 3 ] \
  && for i in 0 1 2; do pvc_bound $NS www-web-$i || return 1; done \
  && pod_running $NS client && exec_contient $NS client "web-1" -- wget -qO- -T 3 http://web-1.web; }
exercice "Ex.1 — StatefulSet web (3 Pods prêts, PVC www-web-N) et DNS web-1.web" \
  "serviceName doit désigner un Service headless ; le template de volume doit s'appeler www." ex1

ex2() { [ "$(kget $NS pod/web-1 '{.spec.volumes[?(@.name=="www")].persistentVolumeClaim.claimName}')" = www-web-1 ] \
  && [ "$(kget $NS sts/web '{.spec.replicas}')" = 3 ]; }
exercice "Ex.2 — web-1 retrouve sa PVC www-web-1, StatefulSet revenu à 3 réplicas" \
  "Après la réduction, pense à remettre 3 réplicas." ex2

ex3() { local d r; d=$(kget $NS ds/agent '{.status.desiredNumberScheduled}'); r=$(kget $NS ds/agent '{.status.numberReady}')
  [ -n "$d" ] && [ "$d" -ge 1 ] && [ "$d" = "$r" ] \
    && $KUBECTL logs -n $NS -l app=agent --tail=5 2>/dev/null | grep -q "$($KUBECTL get nodes -o jsonpath='{.items[0].metadata.name}')"; }
exercice "Ex.3 — DaemonSet agent prêt sur chaque nœud et affichant le nom du nœud" \
  "Le nom du nœud s'obtient avec fieldRef (Downward API) sur spec.nodeName." ex3

ex4a() { [ "$(kget $NS job/lot '{.spec.completions}')" = 4 ] && [ "$(kget $NS job/lot '{.spec.parallelism}')" = 2 ] \
  && [ "$(kget $NS job/lot '{.status.succeeded}')" = 4 ]; }
exercice "Ex.4a — Job lot : 4 succès, 2 en parallèle" \
  "Deux champs de spec règlent le nombre de succès attendus et le nombre de Pods simultanés." ex4a

ex4b() { [ "$(kget $NS job/echec '{.spec.backoffLimit}')" = 2 ] \
  && [ "$(kget $NS job/echec '{.status.conditions[?(@.type=="Failed")].status}')" = True ]; }
exercice "Ex.4b — Job echec : backoffLimit 2 atteint, Job en échec" \
  "Le conteneur doit sortir avec un code non nul ; restartPolicy Never." ex4b

ex5() { [ "$(kget $NS cronjob/horloge '{.spec.schedule}')" = "* * * * *" ] || [ "$(kget $NS cronjob/horloge '{.spec.schedule}')" = "*/1 * * * *" ]; }
ex5b() { ex5 && [ "$(kget $NS cronjob/horloge '{.spec.successfulJobsHistoryLimit}')" = 2 ] \
  && [ -n "$(kget $NS cronjob/horloge '{.status.lastSuccessfulTime}')" ]; }
exercice "Ex.5 — CronJob horloge chaque minute, historique de 2, au moins une exécution réussie" \
  "Vérifie la syntaxe cron (5 champs) et attends au moins une minute." ex5b

ex6() { [ -n "$(kget task-manager cronjob/sauvegarde '{.spec.schedule}')" ] && pvc_bound task-manager sauvegardes \
  && [ "$(kget task-manager job/sauvegarde-manuelle '{.status.succeeded}')" = 1 ] \
  && $KUBECTL logs -n task-manager job/sauvegarde-manuelle 2>/dev/null | grep -q "Sauvegarde écrite"; }
exercice "Ex.6 — Fil rouge : CronJob sauvegarde et Job sauvegarde-manuelle réussi" \
  "kubectl create job peut partir d'un CronJob existant ; en cas d'échec, lis les journaux du Job." ex6

bilan
