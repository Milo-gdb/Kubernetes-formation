#!/usr/bin/env bash
# Vérification du TD bonus 02 — Interfaces web
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/lib.sh"
NS=headlamp
SA="system:serviceaccount:headlamp:observateur"

titre "TD bonus 02 — Headlamp et Kubernetes Dashboard"
exiger_cluster

ex1() { deploy_pret $NS headlamp && svc_a_endpoints $NS headlamp && http_port_forward $NS svc/headlamp 80 / "Headlamp"; }
exercice "Ex.1 — Headlamp installé dans headlamp, Service joignable" \
  "La release Helm doit s'appeler headlamp dans le namespace headlamp ; vérifie que le Pod est prêt." ex1

ex2() { ressource_existe $NS serviceaccount observateur \
  && [ "$($KUBECTL auth can-i list pods -A --as=$SA 2>/dev/null)" = yes ] \
  && [ "$($KUBECTL auth can-i delete pods -n task-manager --as=$SA 2>/dev/null)" = no ] \
  && [ "$($KUBECTL auth can-i get secrets -n task-manager --as=$SA 2>/dev/null)" = no ] \
  && $KUBECTL create token observateur -n $NS --duration=10m >/dev/null 2>&1; }
exercice "Ex.2 — ServiceAccount observateur : lecture du cluster, aucune modification, pas de Secrets" \
  "Un ClusterRole fourni par Kubernetes fait exactement cela ; il doit être lié à l'échelle du cluster." ex2

exercice "Ex.3 — Headlamp joignable sur http://headlamp.local via l'Ingress" \
  "Un Ingress de classe traefik doit router l'hôte headlamp.local vers le Service headlamp." \
  http_ingress headlamp.local / "Headlamp"

ex4() { deploy_pret kubernetes-dashboard kubernetes-dashboard \
  && http_port_forward kubernetes-dashboard svc/kubernetes-dashboard 443 / \
  && [ -s "$HOME/formation-k8s/bonus02/comparaison.md" ] \
  && grep -qi headlamp "$HOME/formation-k8s/bonus02/comparaison.md"; }
exercice "Ex.4 — Kubernetes Dashboard accessible en HTTPS et comparaison rédigée" \
  "Le Dashboard s'installe dans son propre namespace ; le Service écoute en 443. Rédige aussi comparaison.md." ex4

bilan
