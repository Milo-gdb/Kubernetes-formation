# Chart Helm task-manager

Chart de l'application fil rouge (chapitre [12](../../../12-helm-ecosysteme/lecon.md)) : frontend nginx, API PostgREST et PostgreSQL en StatefulSet, avec Services, Ingress, ConfigMaps, Secrets, sondes, ressources, HPA, NetworkPolicy et sauvegarde optionnelles.

## Installation

```bash
helm install task-manager fil-rouge/12-helm/task-manager -n tm-helm --create-namespace \
  --set ingress.host=helm.task-manager.local --set ingress.apiHost=""
```

## Valeurs principales

| Clé | Défaut | Description |
|---|---|---|
| `frontend.image.tag` | `1.30-alpine` | version de nginx |
| `frontend.replicas` / `api.replicas` | `2` | réplicas (ignorés si `autoscaling.enabled`) |
| `api.image.tag` | `v16.5` | version de PostgREST |
| `postgres.user` / `postgres.database` | `taskmanager` | identifiants de la base |
| `postgres.password` | `""` | vide = mot de passe aléatoire généré puis conservé (`lookup`) |
| `postgres.persistence.size` | `1Gi` | taille du volume de données |
| `postgres.persistence.storageClass` | `""` | vide = StorageClass par défaut |
| `ingress.enabled` | `true` | crée l'Ingress |
| `ingress.className` | `traefik` | classe d'Ingress |
| `ingress.host` | `task-manager.local` | domaine du frontend |
| `ingress.apiHost` | `api.task-manager.local` | domaine de l'API (vide = non exposée) |
| `autoscaling.enabled` | `false` | HPA sur frontend et API |
| `networkPolicy.enabled` | `true` | seuls l'API et la sauvegarde joignent PostgreSQL |
| `backup.enabled` | `false` | CronJob `pg_dump` quotidien + PVC |
| `backup.schedule` / `backup.keep` | `0 2 * * *` / `7` | planification, nombre de sauvegardes gardées |

Toutes les valeurs sont commentées dans [`values.yaml`](values.yaml).

## Notes

- Avec `backup.enabled=true` et une StorageClass `WaitForFirstConsumer` (k3s), n'utilise pas `helm install --wait` : la PVC des sauvegardes reste `Pending` jusqu'à la première exécution du CronJob.
- Récupérer le mot de passe : `kubectl get secret -n tm-helm task-manager-postgres -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d`.
