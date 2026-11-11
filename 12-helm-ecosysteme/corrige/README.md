# Corrigé TD 12

## Exercice 1

```bash
helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo update
helm search repo podinfo
helm show values podinfo/podinfo | grep -nE '^replicaCount|^ui:|message'
helm install demo podinfo/podinfo -n td-12 --create-namespace --set replicaCount=2
```

`replicaCount` règle le nombre de réplicas, `ui.message` le message.

## Exercice 2 — [`demo-valeurs.yaml`](demo-valeurs.yaml)

```bash
helm upgrade demo podinfo/podinfo -n td-12 -f demo-valeurs.yaml
helm get values demo -n td-12
kubectl port-forward -n td-12 svc/demo-podinfo 9898:9898 &
curl -s localhost:9898 | grep message          # "message": "Bonjour Helm"
helm history demo -n td-12
helm rollback demo 1 -n td-12                  # révision 3 = copie de la 1 (sans message)
helm upgrade demo podinfo/podinfo -n td-12 -f demo-valeurs.yaml   # révision 4
```

`replicaCount: 2` figure dans le fichier : sans lui, l'upgrade repartirait des défauts du chart (1 réplica), puisque les `--set` de l'installation ne sont pas conservés.

## Exercice 3 — [`mon-site/`](mon-site/)

Fichiers modifiés par rapport à `helm create` : `values.yaml` (image, `message`), `templates/configmap.yaml` (nouveau), `templates/deployment.yaml` (volume + montage).

```bash
cd ~/formation-k8s/ch12 && helm create mon-site
# ... modifications ...
helm lint mon-site
helm template essai mon-site | grep -A3 index.html
helm install site mon-site -n td-12 --set message="Déployé par Helm"
kubectl port-forward -n td-12 svc/site-mon-site 8080:80 &
curl -s localhost:8080                         # Déployé par Helm
```

Les sondes générées par `helm create` testent `/` : la page doit donc exister, c'est le cas grâce au ConfigMap.

## Exercice 4

```bash
helm install task-manager fil-rouge/12-helm/task-manager -n tm-helm --create-namespace \
  --set ingress.host=helm.task-manager.local --set ingress.apiHost= --set autoscaling.enabled=true
kubectl get secret -n tm-helm task-manager-postgres -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d; echo
helm upgrade task-manager fil-rouge/12-helm/task-manager -n tm-helm --reuse-values --set frontend.image.tag=1.29-alpine
kubectl get secret -n tm-helm task-manager-postgres -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d; echo   # identique
curl --resolve helm.task-manager.local:80:<IP> http://helm.task-manager.local/api/tasks
```

Le mot de passe est **identique** : le helper `task-manager.password` relit le Secret existant avec `lookup` au lieu d'en générer un nouveau.

Bonus :

```bash
helm upgrade task-manager fil-rouge/12-helm/task-manager -n tm-helm --reuse-values --set backup.enabled=true
kubectl create job -n tm-helm --from=cronjob/task-manager-sauvegarde sauvegarde-test
kubectl logs -n tm-helm job/sauvegarde-test
```
