#!/usr/bin/env bash
# Vérification du TD 05 — Services
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/lib.sh"
NS=td-05

titre "TD 05 — Services"
exiger_cluster

ex1() { deploy_pret $NS whoami 2 && svc_type $NS whoami ClusterIP && svc_a_endpoints $NS whoami \
  && http_port_forward $NS svc/whoami 80 / "Hostname"; }
exercice "Ex.1 — Deployment whoami (2 réplicas) exposé par le Service ClusterIP whoami" \
  "Le selector du Service doit reprendre exactement les labels des Pods ; regarde les endpoints." ex1

noeud_ip() { $KUBECTL get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}'; }
ex2() { svc_type $NS whoami-nodeport NodePort && [ "$(kget $NS svc/whoami-nodeport '{.spec.ports[0].nodePort}')" = 30500 ] \
  && http_local "http://$(noeud_ip):30500/" "Hostname"; }
exercice "Ex.2 — Service whoami-nodeport joignable sur <IP-nœud>:30500" \
  "type: NodePort et le champ nodePort dans la définition du port." ex2

ex3() { [ "$(kget $NS svc/whoami-headless '{.spec.clusterIP}')" = None ] && svc_a_endpoints $NS whoami-headless; }
exercice "Ex.3 — Service headless whoami-headless" \
  "Un Service headless n'a pas d'IP virtuelle : un champ de spec permet de le demander." ex3

ex4() { pod_running $NS client && exec_contient $NS client "Address" -- nslookup whoami.$NS.svc.cluster.local; }
exercice "Ex.4 — Pod client en Running et résolution DNS du Service" \
  "Le Pod client doit rester en vie (commande sleep) ; teste nslookup depuis l'intérieur." ex4

ex5() { [ "$(kget $NS svc/whoami '{.spec.selector.app}')" = whoami ]; }
exercice "Ex.5 — Sélecteur du Service whoami rétabli" \
  "Compare le selector du Service aux labels des Pods (kubectl get pods --show-labels)." ex5

ex6() {
  svc_type task-manager frontend NodePort && [ "$(kget task-manager svc/frontend '{.spec.ports[0].nodePort}')" = 30080 ] \
    && svc_a_endpoints task-manager frontend && svc_a_endpoints task-manager api && svc_a_endpoints task-manager postgres
}
exercice "Ex.6a — Fil rouge : Services frontend (NodePort 30080), api et postgres avec endpoints" \
  "Vérifie noms, types, sélecteurs (app=frontend/api/postgres) et ports cibles." ex6

ex6b() { http_port_forward task-manager svc/frontend 80 / "nginx" && http_port_forward task-manager svc/api 3000 / ; }
exercice "Ex.6b — Fil rouge : frontend et api répondent en HTTP via leur Service" \
  "Si l'API renvoie une erreur, lis ses journaux : arrive-t-elle à joindre le Service postgres ?" ex6b

bilan
