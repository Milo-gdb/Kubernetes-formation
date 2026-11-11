#!/usr/bin/env bash
# Vérification du TD 06 — Ingress
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/lib.sh"
NS=td-06

titre "TD 06 — Ingress"
exiger_cluster

ex1() { $KUBECTL get ingressclass traefik >/dev/null 2>&1 && pods_running kube-system app.kubernetes.io/name=traefik; }
exercice "Ex.1 — Contrôleur Traefik et IngressClass présents" \
  "Liste les IngressClass et les Pods de kube-system ; Traefik a-t-il été désactivé à l'installation de k3s ?" ex1

ex2a() { deploy_pret $NS app-a 1 && deploy_pret $NS app-b 1 && svc_a_endpoints $NS app-a && svc_a_endpoints $NS app-b; }
exercice "Ex.2a — Deployments et Services app-a / app-b opérationnels" \
  "Chaque Service doit sélectionner les Pods de son application et avoir des endpoints." ex2a

ex2b() { ressource_existe $NS ingress chemins && http_ingress demo.local /a "Name: app-a" && http_ingress demo.local /b "Name: app-b"; }
exercice "Ex.2b — Ingress chemins : demo.local/a → app-a, demo.local/b → app-b" \
  "Vérifie host, path, pathType et backend ; as-tu passé l'argument --name à whoami ?" ex2b

ex3() { ressource_existe $NS ingress hotes && http_ingress a.demo.local / "Name: app-a" && http_ingress b.demo.local / "Name: app-b"; }
exercice "Ex.3 — Ingress hotes : a.demo.local → app-a, b.demo.local → app-b" \
  "Une règle par hôte, chacune avec un chemin /." ex3

ex4() { ressource_existe task-manager ingress task-manager && http_ingress task-manager.local / && http_ingress api.task-manager.local /; }
exercice "Ex.4a — Fil rouge : task-manager.local et api.task-manager.local répondent via l'Ingress" \
  "Deux règles host dans l'Ingress task-manager, vers les Services frontend:80 et api:3000." ex4

ex4b() { getent hosts task-manager.local >/dev/null && getent hosts api.task-manager.local >/dev/null; }
exercice "Ex.4b — Fil rouge : les deux noms sont résolus localement (/etc/hosts)" \
  "Ajoute une ligne '<IP> task-manager.local api.task-manager.local' dans /etc/hosts." ex4b

bilan
