# Corrigé TD 10

```bash
kubectl apply -f td10.yaml
kubectl apply -f networkpolicy.yaml
```

## Exercice 1

Voir [`td10.yaml`](td10.yaml). Le Deployment n'a pas de `resources`, mais le **LimitRange** injecte les valeurs par défaut à la création des Pods (`kubectl get pod <pod> -o yaml | grep -A4 resources`). Sans LimitRange, le quota sur `requests.cpu` ferait **refuser** tous les Pods.

```bash
kubectl scale deploy remplissage -n td-10 --replicas=15
kubectl get pods -n td-10                       # 10 Pods au maximum dans le namespace (quota "pods: 10")
kubectl describe rs -n td-10 -l app=remplissage | grep -A3 Events
#  Warning  FailedCreate ... exceeded quota: quota, requested: pods=1, used: pods=10, limited: pods=10
kubectl describe resourcequota quota -n td-10
kubectl scale deploy remplissage -n td-10 --replicas=3
```

Le refus apparaît sur le **ReplicaSet**, pas sur le Deployment ni sur des Pods (qui n'ont jamais été créés).

## Exercice 2

```bash
SA=system:serviceaccount:td-10:lecteur
kubectl auth can-i list pods -n td-10 --as=$SA          # yes
kubectl auth can-i delete pods -n td-10 --as=$SA        # no
kubectl auth can-i get secrets -n td-10 --as=$SA        # no
kubectl auth can-i list pods -n kube-system --as=$SA    # no
kubectl auth can-i --list -n td-10 --as=$SA
```

## Exercice 3 — [`creer-kubeconfig.sh`](creer-kubeconfig.sh)

```bash
./creer-kubeconfig.sh
export KUBECONFIG=~/formation-k8s/ch10/lecteur.kubeconfig
kubectl get pods                    # OK
kubectl delete pod serveur          # Error from server (Forbidden): ... cannot delete resource "pods"
unset KUBECONFIG
```

Le jeton créé par `kubectl create token` expire (ici après 24 h) : c'est volontaire. Les anciens Secrets de type `service-account-token` (jetons sans expiration) sont déconseillés.

## Exercice 4

RoleBinding `deployeur-edit` vers le **ClusterRole `edit`** : les droits du ClusterRole, limités au namespace du RoleBinding.

```bash
kubectl auth can-i create deployments -n td-10 --as=system:serviceaccount:td-10:deployeur   # yes
kubectl auth can-i create deployments -n default --as=system:serviceaccount:td-10:deployeur # no
```

## Exercice 5 — [`networkpolicy.yaml`](networkpolicy.yaml)

```bash
kubectl exec -n td-10 autorise -- wget -qO- -T 3 http://serveur | head -4   # page nginx
kubectl exec -n td-10 intrus -- wget -qO- -T 3 http://serveur               # wget: download timed out
```

La résolution DNS fonctionne toujours pour `intrus` (la politique ne filtre que l'**entrée** des Pods `role=serveur`).

## Exercice 6 — [`fil-rouge-rbac.yaml`](fil-rouge-rbac.yaml)

```bash
kubectl apply -f fil-rouge-rbac.yaml
kubectl auth can-i list pods -n task-manager --as=system:serviceaccount:task-manager:observateur      # yes
kubectl auth can-i get secrets -n task-manager --as=system:serviceaccount:task-manager:observateur    # no
kubectl run -n task-manager test-nc --rm -it --image=busybox:1.37 --restart=Never -- nc -zv -w 3 postgres 5432
# délai dépassé : le Pod de test n'a pas le label app=api
curl -s http://task-manager.local/api/tasks | head -c 100   # l'application fonctionne toujours
```
