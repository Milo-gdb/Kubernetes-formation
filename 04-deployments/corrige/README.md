# Corrigé TD 04

```bash
kubectl create namespace td-04
```

## Exercice 1 — [`web.yaml`](web.yaml)

```bash
kubectl apply -f web.yaml
kubectl get deploy,rs,pods -n td-04
```

Nom d'un Pod : `<deployment>-<hash du template>-<suffixe aléatoire>`, par ex. `web-6d8f5b7c9-x2k4p`. Le hash identifie le ReplicaSet, donc la version du template.

## Exercice 2

```bash
kubectl delete pod -n td-04 "$(kubectl get pod -n td-04 -l app=web -o name | head -1 | cut -d/ -f2)"
kubectl get pods -n td-04      # un nouveau Pod apparaît aussitôt
# éditer replicas: 5 dans web.yaml
kubectl apply -f web.yaml
```

Le ReplicaSet constate 2 Pods au lieu de 3 et en recrée un.

## Exercice 3

```bash
kubectl set image -n td-04 deployment/web nginx=nginx:1.30-alpine
# ou : modifier l'image dans web.yaml puis kubectl apply -f web.yaml
kubectl rollout status -n td-04 deployment/web
kubectl rollout history -n td-04 deployment/web
kubectl get rs -n td-04        # deux ReplicaSets : l'ancien à 0, le nouveau à 5
```

## Exercice 4

```bash
kubectl set image -n td-04 deployment/web nginx=nginx:9.99-alpine
kubectl get pods -n td-04      # quelques Pods en ErrImagePull/ImagePullBackOff, les autres toujours Running
kubectl rollout undo -n td-04 deployment/web
kubectl rollout status -n td-04 deployment/web
kubectl rollout history -n td-04 deployment/web
```

Le service n'est **pas** interrompu : seuls `maxSurge` + `maxUnavailable` Pods sont touchés, et les anciens Pods restent tant que les nouveaux ne sont pas prêts. Après le `undo`, la révision 2 (1.30) est « reprise » sous un nouveau numéro : l'historique contient alors les révisions 1, 3 et 4.

!!! note
    Si tu as modifié l'image par `kubectl set image`, pense à reporter la version finale dans ton fichier YAML : sinon, ton prochain `kubectl apply` réintroduirait l'ancienne image. Le fichier doit rester la source de vérité.

## Exercice 5

```bash
kubectl delete pod frontend -n task-manager
kubectl apply -f fil-rouge/04-deployment/
kubectl get deploy -n task-manager
kubectl logs -n task-manager deploy/api
```

L'API journalise des erreurs de connexion : le nom `postgres` n'est résolu par aucun DNS, car aucun **Service** n'existe encore. On le crée au chapitre 05. Voir [`fil-rouge/04-deployment/`](../../fil-rouge/04-deployment/10-frontend-deployment.yaml).
