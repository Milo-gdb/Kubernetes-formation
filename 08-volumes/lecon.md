# Chapitre 08 — Volumes et stockage persistant

> **Objectifs** : comprendre pourquoi le système de fichiers d'un conteneur est éphémère, distinguer volumes éphémères et persistants, et maîtriser le trio PersistentVolume / PersistentVolumeClaim / StorageClass.
>
> **Durée estimée** : 2 h 30 — **Fil rouge** : les tâches survivent au redémarrage de PostgreSQL.

---

## 1. Le problème : un disque qui s'efface

Le système de fichiers d'un conteneur est une couche inscriptible posée sur l'image (chapitre 01). Quand le conteneur redémarre — plantage, mise à jour, rescheduling — cette couche est **perdue**. Pour un serveur web sans état, ce n'est pas grave. Pour PostgreSQL, c'est la perte de toutes les données.

Teste-le au chapitre 07 : crée des tâches, puis `kubectl delete pod -l app=postgres` : le nouveau Pod repart d'une base vide.

Un **volume** est un répertoire accessible aux conteneurs d'un Pod, dont la durée de vie et le support dépendent de son **type**.

## 2. Panorama des volumes

| Catégorie | Types | Durée de vie |
|---|---|---|
| **Éphémères** | `emptyDir`, `configMap`, `secret`, `downwardAPI`, `projected` | celle du **Pod** |
| **Liés au nœud** | `hostPath`, `local` | celle des fichiers du nœud |
| **Persistants** | `persistentVolumeClaim` → stockage réseau ou local (CSI) | **indépendante** des Pods |

### `emptyDir` (rappel du chapitre 03)

Créé vide quand le Pod est placé sur un nœud, partagé entre ses conteneurs, supprimé avec le Pod. Il **survit** au redémarrage d'un conteneur, pas à la suppression du Pod. `medium: Memory` le place en RAM (tmpfs).

### `hostPath` : à manier avec précaution

```yaml
volumes:
  - name: logs
    hostPath:
      path: /var/log
      type: Directory
```

Monte un répertoire **du nœud**. Utile pour des agents système (collecte de journaux, supervision), mais :

- les données restent sur **un** nœud : si le Pod est replanifié ailleurs, il ne les retrouve pas ;
- c'est une brèche de sécurité potentielle (accès au système de fichiers de l'hôte) ; il est souvent interdit par les politiques de sécurité.

## 3. Le stockage persistant : trois objets

Kubernetes sépare **qui fournit** le stockage de **qui le consomme** :

```text
  Développeur                          Administrateur / provisionneur
 ┌─────────────────────┐              ┌──────────────────────────────┐
 │ PersistentVolume-   │   liaison    │ PersistentVolume (PV)        │
 │ Claim (PVC)         │ ◄──────────► │ 1Gi, RWO, sur /var/lib/...   │
 │ « je veux 1Gi RWO » │   (bind)     │ ou un disque cloud, NFS...   │
 └─────────▲───────────┘              └──────────────▲───────────────┘
           │ utilisé par                             │ créé à la demande par
       ┌───┴───┐                         ┌───────────┴──────────┐
       │  Pod  │                         │ StorageClass         │
       └───────┘                         │ (provisionneur)      │
                                         └──────────────────────┘
```

| Objet | Portée | Rôle |
|---|---|---|
| **PersistentVolume (PV)** | cluster | Un morceau de stockage réel, avec sa capacité, ses modes d'accès, sa politique de récupération. |
| **PersistentVolumeClaim (PVC)** | namespace | Une **demande** de stockage : taille, mode d'accès, classe. Le Pod référence la PVC, jamais directement le PV. |
| **StorageClass** | cluster | Un « type » de stockage et le **provisionneur** capable de créer des PV à la demande. |

### Provisionnement statique ou dynamique

- **Statique** : l'administrateur crée des PV à l'avance ; une PVC se lie à un PV compatible.
- **Dynamique** : la PVC nomme une StorageClass ; le provisionneur crée automatiquement un PV adapté. C'est le mode normal aujourd'hui.

Dans k3s, la StorageClass par défaut est **`local-path`** (provisionneur `rancher.io/local-path`) : chaque PV est un répertoire sous `/var/lib/rancher/k3s/storage/` du nœud qui exécute le Pod. Simple et parfait pour apprendre, mais **lié à un nœud** : en production multi-nœuds, on utilise un stockage réseau (Longhorn, Ceph/Rook, disques cloud, NFS…) via un pilote **CSI**.

```bash
kubectl get storageclass
# NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE
# local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer
```

`WaitForFirstConsumer` : la PVC reste **Pending** tant qu'aucun Pod ne l'utilise ; le PV est créé sur le nœud où le Pod est planifié. Une PVC Pending n'est donc pas forcément une erreur.

## 4. Anatomie d'une PVC et de son utilisation

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: local-path     # omis = classe par défaut
  resources:
    requests:
      storage: 1Gi
---
# Dans le template du Pod :
containers:
  - name: postgres
    volumeMounts:
      - name: data
        mountPath: /var/lib/postgresql/data
volumes:
  - name: data
    persistentVolumeClaim:
      claimName: postgres-data
```

### Modes d'accès

| Mode | Abréviation | Signification |
|---|---|---|
| ReadWriteOnce | RWO | lecture/écriture par **un seul nœud** à la fois |
| ReadOnlyMany | ROX | lecture seule par plusieurs nœuds |
| ReadWriteMany | RWX | lecture/écriture par plusieurs nœuds (NFS, CephFS…) |
| ReadWriteOncePod | RWOP | lecture/écriture par **un seul Pod** |

Le mode demandé doit être supporté par le stockage : `local-path` ne fait que du RWO.

### Politique de récupération (`reclaimPolicy`)

| Valeur | À la suppression de la PVC |
|---|---|
| `Delete` | le PV **et les données** sont supprimés (défaut des classes dynamiques) |
| `Retain` | le PV passe en `Released`, les données sont conservées pour une récupération manuelle |

!!! danger "Supprimer une PVC peut supprimer des données"
    Avec `local-path` (politique `Delete`), `kubectl delete pvc postgres-data` ou `kubectl delete namespace task-manager` efface la base. Pour des données précieuses : politique `Retain`, sauvegardes (`pg_dump`, Velero…), et protection RBAC.

### Cycle de vie d'un PV

`Available` → `Bound` (lié à une PVC) → `Released` (PVC supprimée, politique Retain) → réutilisation manuelle. Une PVC est `Pending` puis `Bound`. Kubernetes empêche la suppression effective d'une PVC encore utilisée par un Pod (finaliseur `kubernetes.io/pvc-protection`).

## 5. Bases de données et Deployments : la stratégie Recreate

Avec un volume RWO, la stratégie RollingUpdate démarrerait un nouveau Pod PostgreSQL **avant** d'arrêter l'ancien : deux serveurs sur les mêmes fichiers, ce qui est au mieux bloqué, au pire destructeur. On utilise donc `strategy: Recreate` (arrêt, puis démarrage), comme vu au chapitre 04. Le chapitre 11 présentera l'objet conçu pour ce cas : le **StatefulSet**.

Autre détail propre à l'image PostgreSQL : le point de montage d'un volume peut contenir un répertoire `lost+found` qui fait échouer l'initialisation. On place les données dans un **sous-répertoire** via `PGDATA=/var/lib/postgresql/data/pgdata`.

## 6. Fil rouge : une base persistante

[`fil-rouge/08-volumes/`](../fil-rouge/08-volumes/25-postgres-pvc.yaml) ajoute :

- la PVC `postgres-data` (1Gi, RWO, `local-path`) ;
- dans le Deployment `postgres` : montage de la PVC, `PGDATA` dans un sous-répertoire, stratégie `Recreate`.

Test de persistance :

```bash
curl -s -X POST http://task-manager.local/api/tasks -H 'Content-Type: application/json' -d '{"title":"Survivre au redémarrage"}'
kubectl delete pod -n task-manager -l app=postgres
kubectl rollout status -n task-manager deploy/postgres
curl -s http://task-manager.local/api/tasks | grep Survivre      # toujours là
```

---

## Vocabulaire

| Terme | Définition |
|---|---|
| **Volume** | Répertoire monté dans les conteneurs d'un Pod, dont le cycle de vie dépend de son type. |
| **emptyDir** | Volume vide, créé et détruit avec le Pod. |
| **hostPath** | Volume pointant vers un répertoire du nœud. |
| **PersistentVolume (PV)** | Ressource de stockage du cluster, indépendante des Pods. |
| **PersistentVolumeClaim (PVC)** | Demande de stockage faite par une application dans un namespace. |
| **StorageClass** | Classe de stockage associée à un provisionneur dynamique. |
| **Provisionnement dynamique** | Création automatique d'un PV pour satisfaire une PVC. |
| **CSI** | *Container Storage Interface* : interface standard des pilotes de stockage. |
| **Mode d'accès** | RWO, ROX, RWX, RWOP : qui peut monter le volume et comment. |
| **reclaimPolicy** | Sort du PV et des données quand la PVC est supprimée (Delete / Retain). |
| **WaitForFirstConsumer** | Le PV n'est créé qu'au moment où un Pod utilise la PVC. |
| **local-path** | Provisionneur et StorageClass par défaut de k3s, stockage local au nœud. |
