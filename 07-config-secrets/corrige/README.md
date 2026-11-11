# Corrigé TD 07

Les objets créés impérativement (`fichiers`, `identifiants`) sont volontairement absents de [`td07.yaml`](td07.yaml) : ils montrent les commandes `kubectl create`.

```bash
kubectl create namespace td-07
echo "Bonjour depuis un ConfigMap" > message.txt
kubectl create configmap fichiers -n td-07 --from-file=message.txt
kubectl create secret generic identifiants -n td-07 \
  --from-literal=utilisateur=admin --from-literal=motdepasse=Formation-K8s
kubectl apply -f td07.yaml
```

## Exercice 1

`envFrom.configMapRef` injecte toutes les clés.

```bash
kubectl exec -n td-07 lecteur-env -- env | grep -E 'COULEUR|TAILLE'
```

## Exercice 2

```bash
kubectl logs -n td-07 lecteur-vol -f
kubectl edit configmap fichiers -n td-07     # ou :
kubectl create configmap fichiers -n td-07 --from-literal=message.txt="Message mis à jour" \
  --dry-run=client -o yaml | kubectl apply -f -
```

Le nouveau contenu apparaît en général au bout d’une à deux minutes (le kubelet resynchronise périodiquement les volumes). Une variable d'environnement, elle, ne changerait qu'au redémarrage du conteneur.

## Exercice 3

```bash
kubectl get secret identifiants -n td-07 -o yaml
kubectl get secret identifiants -n td-07 -o jsonpath='{.data.motdepasse}' | base64 -d; echo
kubectl exec -n td-07 lecteur-secret -- sh -c 'echo $DB_PASSWORD; ls /secrets; df -h /secrets'
```

`describe` affiche seulement la taille des valeurs (`motdepasse: 13 bytes`). Le volume est un **tmpfs** : le Secret ne touche jamais le disque du nœud.

## Exercice 4

```bash
kubectl patch configmap version -n td-07 -p '{"data":{"NUMERO":"2"}}'
# The ConfigMap "version" is invalid: data: Forbidden: field is immutable when `immutable` is set
```

## Exercice 5

```bash
kubectl apply -f fil-rouge/07-config-secrets/
kubectl delete pod -n task-manager -l app=postgres      # si la base existait déjà sans le schéma
kubectl rollout status -n task-manager deploy/api
curl http://task-manager.local/api/tasks
grep -n "value:" fil-rouge/07-config-secrets/*-deployment.yaml   # plus aucun mot de passe
```

Voir les manifestes commentés [`05-secrets.yaml`](../../fil-rouge/07-config-secrets/05-secrets.yaml) et [`06-configmaps.yaml`](../../fil-rouge/07-config-secrets/06-configmaps.yaml).
