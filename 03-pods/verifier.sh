#!/usr/bin/env bash
# Vérification du TD 03 — Pods
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/lib.sh"
NS=td-03

titre "TD 03 — Les Pods"
exiger_cluster

exercice "Ex.0 — Namespace td-03 créé" "kubectl create namespace ..." ns_existe $NS

ex1() {
  pod_running $NS web && image_contient $NS pod/web "nginx:1.30-alpine" \
    && [ "$(kget $NS pod/web '{.metadata.labels.app}')" = "web" ]
}
exercice "Ex.1 — Pod web (nginx:1.30-alpine, label app=web) en Running" \
  "Vérifie le nom, le namespace, l'image et le bloc metadata.labels de ton manifeste." ex1

ex1b() { http_port_forward $NS pod/web 80 / "Welcome to nginx"; }
exercice "Ex.1b — Le Pod web répond en HTTP" \
  "Le conteneur doit écouter sur le port 80 ; teste toi-même avec kubectl port-forward." ex1b

ex2() {
  pod_running $NS bavard && [ -n "$(kget $NS pod/bavard '{.spec.containers[0].env[?(@.name=="PRENOM")].value}')" ] \
    && $KUBECTL logs -n $NS bavard --tail=5 2>/dev/null | grep -q "^Bonjour .* depuis Kubernetes"
}
exercice "Ex.2 — Pod bavard : variable PRENOM et message dans les journaux" \
  "Déclare la variable dans 'env' et utilise une boucle shell via command/args ; lis kubectl logs." ex2

ex3() {
  [ "$(kget $NS pod/duo '{.spec.containers[*].name}' | wc -w)" -eq 2 ] && pod_pret $NS duo \
    && [ -n "$(kget $NS pod/duo '{.spec.volumes[?(@.emptyDir)].name}')" ]
}
exercice "Ex.3a — Pod duo : 2 conteneurs prêts et un volume emptyDir" \
  "Les deux conteneurs vont dans la même liste 'containers' ; le volume se déclare dans spec.volumes." ex3

ex3b() { http_port_forward $NS pod/duo 80 / "Heure"; }
exercice "Ex.3b — Le Pod duo sert la page générée (« Heure : ... »)" \
  "Le générateur et nginx doivent monter le MÊME volume, chacun à son propre chemin." ex3b

ex4() { pod_running $NS casse && pod_pret $NS casse; }
exercice "Ex.4 — Pod casse réparé et en Running" \
  "kubectl describe pod casse -n td-03 : lis attentivement la section Events." ex4

ex5() {
  ns_existe task-manager && pods_running task-manager app=frontend 1
}
exercice "Ex.5 — Fil rouge : un Pod app=frontend en Running dans task-manager" \
  "Namespace task-manager, label app: frontend, image nginx." ex5

bilan
