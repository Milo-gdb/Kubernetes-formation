# Corrigé TD 08

```bash
kubectl create namespace td-08
kubectl apply -f td08.yaml -f statique.yaml
```

## Exercice 1

```bash
kubectl exec -n td-08 ephemere -- cat /data/date.txt
kubectl delete pod -n td-08 ephemere && kubectl apply -f td08.yaml
kubectl exec -n td-08 ephemere -- cat /data/date.txt     # nouvelle date : l'ancien fichier a disparu
```

## Exercice 2

La PVC reste **Pending** tant qu'aucun Pod ne l'utilise : la classe `local-path` est en mode `WaitForFirstConsumer`. Dès que le Pod `ecrivain` est planifié, un PV `pvc-<uid>` est créé et la PVC passe **Bound**.

```bash
kubectl get pvc,pv -n td-08
kubectl get pv $(kubectl get pvc donnees -n td-08 -o jsonpath='{.spec.volumeName}') \
  -o jsonpath='{.spec.hostPath.path}{.spec.local.path}{"\n"}'
# /var/lib/rancher/k3s/storage/pvc-..._td-08_donnees
```

## Exercice 3

```bash
kubectl exec -n td-08 deploy/ecrivain -- sh -c 'echo persistant > /data/preuve.txt'
kubectl delete pod -n td-08 -l app=ecrivain
kubectl rollout status -n td-08 deploy/ecrivain
kubectl exec -n td-08 deploy/ecrivain -- sh -c 'cat /data/preuve.txt; wc -l /data/journal.txt'
```

## Exercice 4 — [`statique.yaml`](statique.yaml)

`kubectl get pv pv-manuel` : la colonne **STATUS** passe à `Bound` et la colonne **CLAIM** affiche `td-08/pvc-manuelle`. La classe `manuel` n'a pas de provisionneur : elle sert uniquement d'étiquette pour apparier PV et PVC.

Après `kubectl delete pvc pvc-manuelle -n td-08`, le PV passe en `Released` (politique Retain) et n'est pas réutilisable sans intervention manuelle.

## Exercice 5

```bash
kubectl apply -f fil-rouge/08-volumes/
kubectl get pvc -n task-manager
curl -s -X POST http://task-manager.local/api/tasks -H 'Content-Type: application/json' -d '{"title":"Survivre au redémarrage"}'
kubectl delete pod -n task-manager -l app=postgres
kubectl rollout status -n task-manager deploy/postgres
curl -s http://task-manager.local/api/tasks | grep Survivre
```

**Deux réplicas ?** Avec un volume RWO sur un seul nœud, le second Pod monterait le même répertoire et tenterait de démarrer un second serveur PostgreSQL sur les mêmes fichiers : PostgreSQL le refuse (fichier `postmaster.pid`), le Pod plante en boucle. Répliquer une base demande une réplication applicative (primaire/réplicas, chacun avec **son propre** volume) : c'est le rôle des StatefulSets et des opérateurs (chapitre 11).
