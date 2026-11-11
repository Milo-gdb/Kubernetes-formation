#!/usr/bin/env bash
# Vérification du TD 10 — Namespaces, quotas, RBAC et NetworkPolicies
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/lib.sh"
NS=td-10
SA="system:serviceaccount:$NS"

titre "TD 10 — Namespaces, quotas, RBAC et NetworkPolicies"
exiger_cluster

peut()    { [ "$($KUBECTL auth can-i "$@" 2>/dev/null)" = yes ]; }
ne_peut() { ! peut "$@"; }

ex1a() { [ "$($KUBECTL get ns $NS -o jsonpath='{.metadata.labels.equipe}' 2>/dev/null)" = formation ] \
  && [ "$(kget $NS resourcequota/quota '{.spec.hard.pods}')" = 10 ] \
  && [ "$(kget $NS limitrange/limites '{.spec.limits[0].defaultRequest.cpu}')" = 50m ]; }
exercice "Ex.1a — Namespace td-10 (label equipe=formation), quota et LimitRange" \
  "Vérifie le label du namespace, puis les champs hard du quota et defaultRequest du LimitRange." ex1a

ex1b() { deploy_pret $NS remplissage 3 && [ -z "$(kget $NS deploy/remplissage '{.spec.template.spec.containers[0].resources.requests}')" ] \
  && [ -n "$($KUBECTL get pods -n $NS -l app=remplissage -o jsonpath='{.items[0].spec.containers[0].resources.requests.cpu}' 2>/dev/null)" ]; }
exercice "Ex.1b — remplissage : 3 réplicas, ressources injectées par le LimitRange" \
  "Le Deployment ne doit pas déclarer de ressources : c'est le LimitRange qui les fournit aux Pods." ex1b

ex2() { peut list pods -n $NS --as=$SA:lecteur && peut get pods --subresource=log -n $NS --as=$SA:lecteur \
  && ne_peut delete pods -n $NS --as=$SA:lecteur && ne_peut get secrets -n $NS --as=$SA:lecteur \
  && ne_peut list pods -n kube-system --as=$SA:lecteur; }
exercice "Ex.2 — lecteur : lecture des Pods et journaux, rien d'autre" \
  "Teste toi-même avec kubectl auth can-i --list --as=... ; n'oublie pas la sous-ressource des journaux." ex2

KCFG="${HOME}/formation-k8s/ch10/lecteur.kubeconfig"
ex3() { [ -f "$KCFG" ] && KUBECONFIG="$KCFG" $KUBECTL get pods -n $NS >/dev/null 2>&1 \
  && ! KUBECONFIG="$KCFG" $KUBECTL auth can-i delete pods -n $NS 2>/dev/null | grep -qx yes; }
exercice "Ex.3 — ~/formation-k8s/ch10/lecteur.kubeconfig fonctionne avec les droits de lecteur" \
  "Le kubeconfig doit contenir le serveur, la CA et un jeton (non expiré) du ServiceAccount lecteur." ex3

ex4() { peut create deployments -n $NS --as=$SA:deployeur && peut delete services -n $NS --as=$SA:deployeur \
  && ne_peut create deployments -n default --as=$SA:deployeur && ne_peut create rolebindings -n $NS --as=$SA:deployeur; }
exercice "Ex.4 — deployeur : modification des objets de td-10 uniquement" \
  "Un ClusterRole prédéfini accordé par un RoleBinding reste limité au namespace du binding." ex4

ex5() { ressource_existe $NS networkpolicy serveur-restreint && pod_running $NS autorise && pod_running $NS intrus \
  && exec_contient $NS autorise "nginx" -- wget -qO- -T 3 http://serveur \
  && ! $KUBECTL exec -n $NS intrus -- wget -qO- -T 3 http://serveur >/dev/null 2>&1; }
exercice "Ex.5 — NetworkPolicy : autorise joint serveur, intrus est bloqué" \
  "podSelector désigne les Pods protégés ; from.podSelector désigne les sources autorisées." ex5

ex6a() { peut list pods -n task-manager --as=system:serviceaccount:task-manager:observateur \
  && ne_peut get secrets -n task-manager --as=system:serviceaccount:task-manager:observateur \
  && ne_peut delete pods -n task-manager --as=system:serviceaccount:task-manager:observateur; }
exercice "Ex.6a — Fil rouge : observateur lit task-manager (hors Secrets) sans rien modifier" \
  "Un ClusterRole prédéfini fait exactement cela ; il suffit de le lier dans le bon namespace." ex6a

ex6b() { ressource_existe task-manager networkpolicy postgres-depuis-api \
  && [ "$(kget task-manager networkpolicy/postgres-depuis-api '{.spec.podSelector.matchLabels.app}')" = postgres ] \
  && http_ingress task-manager.local /api/tasks '"title"'; }
exercice "Ex.6b — Fil rouge : PostgreSQL protégé par NetworkPolicy, application fonctionnelle" \
  "Si l'API ne répond plus, vérifie que la politique autorise bien les Pods app=api sur le port 5432." ex6b

bilan
