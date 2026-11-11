#!/usr/bin/env bash
# Vérification du TD 09 — Sondes, ressources et autoscaling
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/lib.sh"
NS=td-09

titre "TD 09 — Sondes, ressources et autoscaling"
exiger_cluster

ex1() { [ -n "$(kget $NS pod/vivant '{.spec.containers[0].livenessProbe.exec.command}')" ] \
  && [ "$(kget $NS pod/vivant '{.status.containerStatuses[0].restartCount}')" -ge 1 ]; }
exercice "Ex.1 — Pod vivant : liveness exec et au moins un redémarrage observé" \
  "La sonde doit être de type exec et le fichier testé doit disparaître ; attends une minute." ex1

ex2() { deploy_pret $NS web 2 && [ -n "$(kget $NS deploy/web '{.spec.template.spec.containers[0].readinessProbe}')" ] \
  && [ -n "$(kget $NS deploy/web '{.spec.template.spec.containers[0].livenessProbe}')" ] \
  && [ -n "$(kget $NS deploy/web '{.spec.template.spec.containers[0].resources.requests.cpu}')" ] \
  && svc_a_endpoints $NS web; }
exercice "Ex.2 — Deployment web : readiness, liveness, requests CPU et Service avec endpoints" \
  "Les deux sondes et les requests se déclarent dans le conteneur du template." ex2

ex3() { [ "$(kget $NS pod/gourmand '{.spec.containers[0].resources.limits.memory}')" = 64Mi ] \
  && kget $NS pod/gourmand '{.status.containerStatuses[0].lastState.terminated.reason}{.status.containerStatuses[0].state.terminated.reason}' | grep -q OOMKilled; }
exercice "Ex.3 — Pod gourmand tué pour dépassement mémoire (OOMKilled)" \
  "Une limite mémoire de 64Mi est nécessaire ; regarde lastState dans le statut du conteneur." ex3

ex4() { [ "$(kget $NS pod/garanti '{.status.qosClass}')" = Guaranteed ]; }
exercice "Ex.4 — Pod garanti en classe QoS Guaranteed" \
  "Toutes les ressources (CPU et mémoire) doivent avoir request = limit." ex4

ex5() { [ "$(kget $NS hpa/web '{.spec.scaleTargetRef.name}')" = web ] && [ "$(kget $NS hpa/web '{.spec.minReplicas}')" = 2 ] \
  && [ "$(kget $NS hpa/web '{.spec.maxReplicas}')" = 6 ] \
  && [ "$(kget $NS hpa/web '{.spec.metrics[0].resource.target.averageUtilization}')" = 50 ] \
  && [ -n "$(kget $NS hpa/web '{.status.currentMetrics[0].resource.current.averageUtilization}')" ]; }
exercice "Ex.5 — HPA web (2 à 6 réplicas, 50 % CPU) avec métriques disponibles" \
  "Si TARGETS affiche <unknown> : requests CPU manquantes ou metrics-server absent ; patiente 1 minute." ex5

ex6a() { for d in frontend api postgres; do
    [ -n "$(kget task-manager deploy/$d '{.spec.template.spec.containers[0].readinessProbe}')" ] || return 1
    [ -n "$(kget task-manager deploy/$d '{.spec.template.spec.containers[0].resources.requests.memory}')" ] || return 1
  done; }
exercice "Ex.6a — Fil rouge : sondes readiness et requests sur frontend, api et postgres" \
  "Applique fil-rouge/09-sondes-ressources/ et compare avec le tableau de la leçon." ex6a

ex6b() { [ "$(kget task-manager hpa/frontend '{.spec.scaleTargetRef.name}')" = frontend ] \
  && [ "$(kget task-manager hpa/api '{.spec.scaleTargetRef.name}')" = api ] \
  && http_ingress task-manager.local /api/tasks; }
exercice "Ex.6b — Fil rouge : HPA frontend et api en place, application joignable" \
  "Deux HPA sont attendus dans task-manager ; l'application doit toujours répondre via l'Ingress." ex6b

bilan
