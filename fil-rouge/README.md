# Fil rouge : l'application task-manager

Le **task-manager** est une petite application de gestion de tâches construite chapitre après chapitre. Chaque dossier contient l'état **complet** de l'application à la fin d'un chapitre : on peut toujours repartir d'une étape avec `kubectl apply -f fil-rouge/<étape>/`.

```text
navigateur ──► Ingress Traefik ──► frontend (nginx, port 80) ──/api/──► API (PostgREST, port 3000) ──► PostgreSQL (5432)
              task-manager.local                                api.task-manager.local
```

| Composant | Image | Rôle |
|---|---|---|
| frontend | `nginx:1.30-alpine` | page web statique, reverse proxy `/api/` vers l'API |
| api | `postgrest/postgrest:v16.5` | API REST générée à partir du schéma PostgreSQL (`GET/POST/PATCH/DELETE /tasks`) |
| postgres | `postgres:17-alpine` | base de données, table `tasks` |

## Progression

| Étape | Chapitre | Ce qui change |
|---|---|---|
| [`03-pod/`](03-pod/10-frontend-pod.yaml) | [03 Pods](../03-pods/lecon.md) | un Pod nginx seul dans le namespace `task-manager` |
| [`04-deployment/`](04-deployment/10-frontend-deployment.yaml) | [04 Deployments](../04-deployments/lecon.md) | frontend, API et PostgreSQL en Deployments |
| [`05-services/`](05-services/40-services.yaml) | [05 Services](../05-services/lecon.md) | Services ClusterIP : les composants se trouvent par DNS |
| [`06-ingress/`](06-ingress/50-ingress.yaml) | [06 Ingress](../06-ingress/lecon.md) | Ingress Traefik, domaines `task-manager.local` et `api.task-manager.local` |
| [`07-config-secrets/`](07-config-secrets/06-configmaps.yaml) | [07 ConfigMaps et Secrets](../07-config-secrets/lecon.md) | identifiants en Secrets, schéma SQL et configuration nginx en ConfigMaps |
| [`08-volumes/`](08-volumes/25-postgres-pvc.yaml) | [08 Volumes](../08-volumes/lecon.md) | PVC `local-path` : les données survivent au Pod |
| [`09-sondes-ressources/`](09-sondes-ressources/60-hpa.yaml) | [09 Sondes, ressources](../09-sondes-ressources-autoscaling/lecon.md) | sondes, requests/limits, HPA |
| [`10-namespaces-rbac/corrige/`](../10-namespaces-rbac/corrige/fil-rouge-rbac.yaml) | [10 RBAC](../10-namespaces-rbac/lecon.md) | ServiceAccount, Role, NetworkPolicy protégeant PostgreSQL |
| [`11-sauvegarde/`](11-sauvegarde/70-sauvegarde.yaml) | [11 Jobs et CronJobs](../11-statefulsets-jobs/lecon.md) | CronJob de sauvegarde `pg_dump` quotidienne |
| [`12-helm/task-manager/`](12-helm/task-manager/README.md) | [12 Helm](../12-helm-ecosysteme/lecon.md) | tout le reste, en un chart paramétrable |

Les chapitres bonus réutilisent l'application : diagnostic d'une panne PostgreSQL avec [k9s](../bonus-01-k9s/td.md), exploration avec [Headlamp](../bonus-02-interfaces-web/td.md) et un [kubeconfig en lecture seule](../bonus-03-lens-alternatives/td.md).

## Déployer l'étape finale sans Helm

```bash
kubectl apply -f fil-rouge/09-sondes-ressources/
kubectl apply -f 10-namespaces-rbac/corrige/fil-rouge-rbac.yaml
kubectl apply -f fil-rouge/11-sauvegarde/
```

!!! warning "Secrets de formation"
    Le mot de passe `ChangeMe-Formation-2026` des étapes 07 à 11 est volontairement visible pour l'apprentissage. Ne réutilise jamais ces fichiers tels quels en production : le chart Helm génère, lui, un mot de passe aléatoire.
