# Chapitre 11 — StatefulSets, DaemonSets, Jobs et CronJobs

> **Objectifs** : choisir le bon contrôleur selon la nature de la charge : application avec état et identité stable, agent présent sur chaque nœud, tâche ponctuelle ou planifiée.
>
> **Durée estimée** : 3 h — **Fil rouge** : sauvegarde quotidienne de la base.

---

## 1. Quel contrôleur pour quelle charge ?

| Contrôleur | Charge typique | Pods |
|---|---|---|
| **Deployment** | service sans état (web, API) | interchangeables, noms aléatoires |
| **StatefulSet** | base de données, file de messages, cluster distribué | identité **stable** : nom, DNS, volume propres |
| **DaemonSet** | agent de nœud (journaux, supervision, réseau) | **un par nœud** |
| **Job** | traitement qui doit **se terminer** (migration, calcul, import) | s'arrêtent une fois réussis |
| **CronJob** | Job **planifié** (sauvegarde, purge, rapport) | un Job par échéance |

## 2. Le StatefulSet

Au chapitre 08, PostgreSQL tournait dans un Deployment à un réplica avec une PVC : ça fonctionne, mais un Deployment ne sait pas gérer **plusieurs** instances avec état. Ses Pods portent des noms aléatoires, partagent le même modèle de volume et sont créés dans le désordre. Un cluster de bases a besoin de l'inverse.

Un **StatefulSet** garantit à chaque Pod :

| Garantie | Exemple avec `postgres` à 3 réplicas |
|---|---|
| **Nom stable et ordonné** | `postgres-0`, `postgres-1`, `postgres-2` — recréé avec le **même** nom |
| **DNS stable** (via un Service headless) | `postgres-0.postgres.task-manager.svc.cluster.local` |
| **Volume propre et persistant** | PVC `data-postgres-0`, `data-postgres-1`… créées par `volumeClaimTemplates`, **réattachées** au Pod du même rang |
| **Ordre** | création 0 → 1 → 2 (chacun attend que le précédent soit prêt), suppression 2 → 1 → 0 |

```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  clusterIP: None              # headless : un enregistrement DNS par Pod
  selector: { app: postgres }
  ports: [{ port: 5432 }]
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres        # le Service headless qui fournit les noms DNS
  replicas: 1
  selector:
    matchLabels: { app: postgres }
  template:
    metadata:
      labels: { app: postgres }
    spec:
      containers:
        - name: postgres
          image: postgres:17-alpine
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:        # une PVC par Pod : data-postgres-0, data-postgres-1...
    - metadata:
        name: data
      spec:
        accessModes: [ReadWriteOnce]
        resources:
          requests:
            storage: 1Gi
```

!!! warning "Ce que le StatefulSet ne fait pas"
    - Il ne **réplique pas les données** : `postgres-1` démarre avec un volume vide. La réplication (primaire/réplicas, élection, bascule) est l'affaire de l'application ou d'un **opérateur** (CloudNativePG, Zalando Postgres Operator…).
    - Réduire le nombre de réplicas ou supprimer le StatefulSet **ne supprime pas** les PVC (comportement par défaut, réglable via `persistentVolumeClaimRetentionPolicy`) : les données sont protégées, mais il faut les nettoyer à la main.

Mises à jour : stratégie `RollingUpdate` (du rang le plus élevé au plus bas, un Pod à la fois) ou `OnDelete`. Le champ `partition` permet un déploiement progressif (seuls les Pods de rang ≥ partition sont mis à jour).

## 3. Le DaemonSet

Un **DaemonSet** exécute une copie d'un Pod sur **chaque nœud** (ou sur ceux qui correspondent à un `nodeSelector`), et en ajoute automatiquement sur les nouveaux nœuds. Exemples : collecteur de journaux (Fluent Bit), exportateur de métriques (node-exporter), composants réseau. Dans k3s, les Pods `svclb-traefik-*` de ServiceLB sont gérés par un DaemonSet.

```bash
kubectl get daemonsets -A
```

Pour tourner aussi sur les nœuds du plan de contrôle, un DaemonSet doit souvent **tolérer** leurs *taints* (`tolerations`).

## 4. Le Job

Un **Job** crée un ou plusieurs Pods et s'assure qu'un nombre donné d'entre eux **se terminent avec succès**.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: migration
spec:
  completions: 1             # nombre de succès attendus
  parallelism: 1             # Pods simultanés
  backoffLimit: 4            # échecs tolérés avant d'abandonner
  activeDeadlineSeconds: 600 # durée maximale du Job
  ttlSecondsAfterFinished: 3600   # suppression automatique après la fin
  template:
    spec:
      restartPolicy: Never   # OBLIGATOIRE : Never ou OnFailure (jamais Always)
      containers:
        - name: migration
          image: mon-app:1.4
          command: ["./migrer.sh"]
```

| `restartPolicy` | En cas d'échec |
|---|---|
| `OnFailure` | le **conteneur** est redémarré dans le même Pod |
| `Never` | un **nouveau Pod** est créé (les Pods en échec restent pour consulter leurs journaux) |

Avec `completions: 5` et `parallelism: 2`, le Job exécute 5 Pods au total, 2 à la fois. Le mode `completionMode: Indexed` donne à chaque Pod un index (`JOB_COMPLETION_INDEX`) pour se répartir un travail.

```bash
kubectl get jobs
kubectl logs job/migration
kubectl wait --for=condition=complete job/migration --timeout=120s
```

## 5. Le CronJob

Un **CronJob** crée un Job selon une planification au format **cron** :

```text
┌──────── minute (0-59)
│ ┌────── heure (0-23)
│ │ ┌──── jour du mois (1-31)
│ │ │ ┌── mois (1-12)
│ │ │ │ ┌ jour de la semaine (0-6, 0 = dimanche)
│ │ │ │ │
0 2 * * *      tous les jours à 2 h
*/15 * * * *   toutes les 15 minutes
0 8 * * 1-5    à 8 h du lundi au vendredi
```

| Champ | Rôle |
|---|---|
| `schedule` | planification cron |
| `timeZone` | fuseau horaire (`Europe/Paris`), UTC par défaut |
| `concurrencyPolicy` | `Allow` (défaut), `Forbid` (sauter si le précédent tourne), `Replace` |
| `startingDeadlineSeconds` | retard maximal toléré pour lancer une exécution manquée |
| `successfulJobsHistoryLimit` / `failedJobsHistoryLimit` | Jobs conservés pour l'historique (3 et 1 par défaut) |
| `suspend` | met la planification en pause |

Lancer immédiatement une exécution, sans attendre l'échéance :

```bash
kubectl create job --from=cronjob/sauvegarde sauvegarde-manuelle
```

## 6. Fil rouge : la sauvegarde

[`fil-rouge/11-sauvegarde/70-sauvegarde.yaml`](../fil-rouge/11-sauvegarde/70-sauvegarde.yaml) ajoute :

- une PVC `sauvegardes` ;
- un CronJob `sauvegarde` qui, chaque nuit à 2 h (heure de Paris), exécute `pg_dump` contre le Service `postgres`, compresse le résultat dans la PVC et ne garde que les 7 dernières sauvegardes ;
- le label `postgres-client: "true"` sur ses Pods, pour que la NetworkPolicy du chapitre 10 les laisse joindre la base.

Le chart Helm du chapitre 12 franchira l'étape suivante : PostgreSQL y est déployé par un **StatefulSet**.

!!! tip "Restaurer une sauvegarde"
    Lance un Pod temporaire qui monte la PVC `sauvegardes`, porte le label autorisé par la NetworkPolicy, et rejoue un fichier avec `psql` :

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: restauration
      namespace: task-manager
      labels: { postgres-client: "true" }
    spec:
      restartPolicy: Never
      containers:
        - name: psql
          image: postgres:17-alpine
          command: ["sh", "-c", "gunzip -c $(ls -1t /sauvegardes/*.sql.gz | head -1) | psql -h postgres"]
          envFrom: []   # PGUSER, PGPASSWORD, PGDATABASE : mêmes secretKeyRef que le CronJob
          volumeMounts: [{ name: s, mountPath: /sauvegardes }]
      volumes: [{ name: s, persistentVolumeClaim: { claimName: sauvegardes } }]
    ```

    Une sauvegarde jamais restaurée n'est pas une sauvegarde : teste la restauration régulièrement.

---

## Vocabulaire

| Terme | Définition |
|---|---|
| **StatefulSet** | Contrôleur donnant à chaque Pod un nom, un DNS et un volume stables et ordonnés. |
| **Service headless** | Service sans ClusterIP, utilisé pour fournir un nom DNS à chaque Pod. |
| **volumeClaimTemplates** | Modèle de PVC créé pour chaque Pod d'un StatefulSet. |
| **Ordinal** | Rang d'un Pod de StatefulSet (0, 1, 2…). |
| **DaemonSet** | Contrôleur qui exécute un Pod sur chaque nœud. |
| **Job** | Contrôleur qui exécute des Pods jusqu'à un nombre de succès donné. |
| **completions / parallelism** | Succès attendus / Pods exécutés simultanément par un Job. |
| **backoffLimit** | Nombre d'échecs tolérés avant de marquer un Job en échec. |
| **CronJob** | Contrôleur qui crée des Jobs selon une planification cron. |
| **concurrencyPolicy** | Comportement d'un CronJob si l'exécution précédente n'est pas terminée. |
| **Opérateur** | Contrôleur spécialisé qui automatise la gestion d'une application complexe (ex. une base répliquée). |
| **Taint / toleration** | Marque repoussant les Pods d'un nœud / autorisation pour un Pod d'y être placé. |
