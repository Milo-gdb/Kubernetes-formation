# Corrigé TD 03

```bash
kubectl create namespace td-03
```

## Exercice 1 — [`web.yaml`](web.yaml)

```bash
kubectl apply -f web.yaml
kubectl get pod web -n td-03 -o wide
kubectl describe pod web -n td-03       # section Events en bas
kubectl port-forward -n td-03 pod/web 8080:80   # puis http://localhost:8080
```

## Exercice 2 — [`bavard.yaml`](bavard.yaml)

```bash
kubectl apply -f bavard.yaml
kubectl logs -n td-03 bavard -f
```

`command` remplace l'ENTRYPOINT de l'image et `args` le CMD. La variable `${PRENOM}` est développée par le shell `sh -c` à l'intérieur du conteneur. (Kubernetes sait aussi substituer `$(PRENOM)` lui-même dans `command`/`args`.)

## Exercice 3 — [`duo.yaml`](duo.yaml)

```bash
kubectl apply -f duo.yaml
kubectl port-forward -n td-03 pod/duo 8080:80 &
watch -n1 curl -s localhost:8080
kubectl exec -n td-03 duo -c horloge -- wget -qO- localhost
```

Piège YAML : la chaîne `echo "Heure : ..."` contient « deux-points + espace ». Écrite directement après `- `, YAML croit lire un dictionnaire et l'API répond `cannot unmarshal object into ... args of type string`. On utilise donc un bloc littéral `|` (ou des guillemets autour de toute la ligne).

Oui, `localhost` fonctionne : les conteneurs d'un même Pod partagent le même espace réseau (même IP, mêmes ports). Note l'option `-c` pour choisir le conteneur.

## Exercice 4 — [`casse.yaml`](casse.yaml)

1. `ErrImagePull` puis `ImagePullBackOff`.
2. `kubectl describe pod casse -n td-03` → Events : `Failed to pull image "nginx:1.30-alpnie": ... not found`. Le tag est mal orthographié.
3. Le champ `image` fait partie des rares champs modifiables d'un Pod, donc `kubectl edit` ou un `apply` corrigé fonctionnent. Mais la plupart des champs (ports, env, volumes…) sont **immuables** : la méthode universelle est de supprimer puis recréer :

```bash
kubectl delete pod casse -n td-03
kubectl apply -f casse.yaml
```

## Exercice 5 — fil rouge

```bash
kubectl apply -f fil-rouge/03-pod/
kubectl get pods -n task-manager --show-labels
```

Voir [`fil-rouge/03-pod/`](../../fil-rouge/03-pod/10-frontend-pod.yaml).
