# Corrigé TD bonus 02

## Exercice 1

```bash
helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/
helm repo update
helm install headlamp headlamp/headlamp -n headlamp --create-namespace
kubectl port-forward -n headlamp svc/headlamp 8080:80
kubectl create token headlamp -n headlamp      # jeton cluster-admin du chart
```

## Exercice 2 — [`observateur.yaml`](observateur.yaml)

```bash
kubectl apply -f observateur.yaml
kubectl create token observateur -n headlamp --duration=8h
kubectl auth can-i delete pods -n task-manager --as=system:serviceaccount:headlamp:observateur   # no
```

La suppression échoue avec une erreur `forbidden` : l'interface relaie la réponse de l'API, qui applique le RBAC du jeton.

## Exercice 3 — [`ingress-headlamp.yaml`](ingress-headlamp.yaml)

```bash
kubectl apply -f ingress-headlamp.yaml
echo "$(kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}') headlamp.local" | sudo tee -a /etc/hosts
curl -s -o /dev/null -w '%{http_code}\n' http://headlamp.local/
```

## Exercice 4

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 8443:443
# https://localhost:8443, accepter le certificat auto-signé, "Token", coller le jeton observateur
```

Exemple de comparaison : [`comparaison.md`](comparaison.md).

## Exercice 5

Le jeton de `headlamp` est `cluster-admin` : quiconque peut le générer (droit `create` sur `serviceaccounts/token` dans `headlamp`) ou l'intercepter contrôle tout le cluster.

```bash
helm upgrade headlamp headlamp/headlamp -n headlamp --reuse-values --set clusterRoleBinding.create=false
```
