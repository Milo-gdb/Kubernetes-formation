# Corrigé TD 11

```bash
kubectl create namespace td-11
kubectl apply -f td11.yaml
```

## Exercice 1

Les Pods sont créés **dans l'ordre** `web-0`, `web-1`, `web-2`, chacun attendant que le précédent soit prêt. Trois PVC apparaissent : `www-web-0`, `www-web-1`, `www-web-2` (nom = `<template>-<pod>`).

```bash
kubectl get pods,pvc -n td-11 -l app=web
kubectl exec -n td-11 client -- wget -qO- http://web-1.web      # web-1
kubectl exec -n td-11 client -- nslookup web                    # les 3 IP des Pods
```

## Exercice 2

```bash
kubectl delete pod web-1 -n td-11
kubectl get pod web-1 -n td-11 -o jsonpath='{.spec.volumes[0].persistentVolumeClaim.claimName}'   # www-web-1
kubectl scale sts web -n td-11 --replicas=2     # web-2 disparaît (le rang le plus élevé)
kubectl get pvc -n td-11                        # www-web-2 est toujours là
kubectl scale sts web -n td-11 --replicas=3     # web-2 revient et retrouve www-web-2
```

## Exercice 3

Un seul Pod sur un cluster à un nœud : un DaemonSet place exactement un Pod par nœud éligible.

```bash
kubectl logs -n td-11 -l app=agent       # Agent actif sur <nom-du-nœud>
```

## Exercice 4

```bash
kubectl get jobs -n td-11
# lot     Complete   4/4
# echec   Failed     0/1
kubectl get pods -n td-11 -l job-name=echec      # 3 Pods en Error : 1 essai + 2 nouvelles tentatives
kubectl describe job echec -n td-11 | grep -i backoff
# Warning  BackoffLimitExceeded  Job has reached the specified backoff limit
```

## Exercice 5

```bash
kubectl get cronjob,jobs -n td-11
kubectl logs -n td-11 job/$(kubectl get jobs -n td-11 -o name | grep horloge | tail -1 | cut -d/ -f2)
```

Pense à supprimer `horloge` après le TD (`kubectl delete cronjob horloge -n td-11`) : il tourne indéfiniment.

## Exercice 6

```bash
kubectl apply -f fil-rouge/11-sauvegarde/
kubectl create job -n task-manager --from=cronjob/sauvegarde sauvegarde-manuelle
kubectl wait -n task-manager --for=condition=complete job/sauvegarde-manuelle --timeout=120s
kubectl logs -n task-manager job/sauvegarde-manuelle
# Sauvegarde écrite : /sauvegardes/taskmanager-20261111-150102.sql.gz (1234 octets)
```

Sans le label `postgres-client: "true"`, la NetworkPolicy `postgres-depuis-api` (chapitre 10) bloquerait la connexion : `pg_dump` échouerait sur un délai de connexion, et le Job finirait en échec après ses tentatives.
