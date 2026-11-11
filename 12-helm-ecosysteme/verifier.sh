#!/usr/bin/env bash
# Vérification du TD 12 — Helm
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/lib.sh"
NS=td-12
CH12="${HOME}/formation-k8s/ch12"

titre "TD 12 — Helm"
exiger_cluster

statut_release() { helm status "$2" -n "$1" -o json 2>/dev/null | grep -o '"status":"[a-z-]*"' | head -1 | cut -d'"' -f4; }

exercice "Helm est installé" "Installe le binaire helm (voir la leçon) et vérifie 'helm version'." commande_existe helm

ex1() { [ "$(statut_release $NS demo)" = deployed ] && helm list -n $NS -o json 2>/dev/null | grep -q '"chart":"podinfo-' \
  && deploy_pret $NS demo-podinfo 2; }
exercice "Ex.1 — Release demo (chart podinfo) déployée avec 2 réplicas" \
  "helm list -n td-12 ; le nombre de réplicas se règle par une valeur du chart." ex1

ex2() { [ -f "$CH12/demo-valeurs.yaml" ] && [ "$(helm history demo -n $NS -o json 2>/dev/null | grep -o '"revision":' | wc -l)" -ge 4 ] \
  && helm history demo -n $NS 2>/dev/null | grep -qi "rollback" \
  && helm get values demo -n $NS 2>/dev/null | grep -q "Bonjour Helm" \
  && http_port_forward $NS svc/demo-podinfo 9898 / "Bonjour Helm" && deploy_pret $NS demo-podinfo 2; }
exercice "Ex.2 — demo mise à jour (message « Bonjour Helm »), rollback visible dans l'historique" \
  "Il faut une mise à jour, un rollback puis une nouvelle mise à jour avec ton fichier de valeurs." ex2

ex3() { [ -f "$CH12/mon-site/Chart.yaml" ] && helm lint "$CH12/mon-site" >/dev/null 2>&1 \
  && helm template essai "$CH12/mon-site" 2>/dev/null | grep -q "Mon premier chart" \
  && [ "$(statut_release $NS site)" = deployed ] \
  && http_port_forward $NS "svc/$($KUBECTL get svc -n $NS -l app.kubernetes.io/instance=site -o jsonpath='{.items[0].metadata.name}')" 80 / "Déployé par Helm"; }
exercice "Ex.3 — Chart mon-site valide, release site affichant le message passé à l'installation" \
  "La valeur message doit être utilisée dans un ConfigMap modèle monté comme page d'accueil." ex3

ex4() { [ "$(statut_release tm-helm task-manager)" = deployed ] \
  && [ "$(kget tm-helm sts/task-manager-postgres '{.status.readyReplicas}')" = 1 ] \
  && ressource_existe tm-helm hpa task-manager-api \
  && http_ingress helm.task-manager.local /api/tasks '"title"'; }
exercice "Ex.4 — Fil rouge : release task-manager déployée dans tm-helm et joignable" \
  "Vérifie les valeurs passées (ingress.host, autoscaling.enabled) avec helm get values -n tm-helm task-manager." ex4

ex4b() { image_contient tm-helm deployment/task-manager-frontend "nginx:1.29-alpine" \
  && [ "$(helm history task-manager -n tm-helm -o json 2>/dev/null | grep -o '"revision":' | wc -l)" -ge 2 ]; }
exercice "Ex.4b — Fil rouge : mise à jour vers nginx:1.29-alpine effectuée" \
  "Utilise helm upgrade avec --reuse-values pour ne pas perdre les autres valeurs." ex4b

bilan
