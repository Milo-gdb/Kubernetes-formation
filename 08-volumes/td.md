# TD 08 — Volumes

> Namespace de travail : **`td-08`**. Manifestes dans `~/formation-k8s/ch08/`.
> Vérification : `./08-volumes/verifier.sh`

## Exercice 1 — Constater la perte de données

1. Crée un Pod **`ephemere`** (`busybox:1.37`) qui écrit la date dans `/data/date.txt` au démarrage puis dort (`sleep 3600`), **sans volume**.
2. Lis le fichier, supprime le Pod, recrée-le : la date a-t-elle changé ? Garde le Pod `ephemere` en fonctionnement pour la suite.

## Exercice 2 — Provisionnement dynamique

1. Crée une PVC **`donnees`** de **200Mi**, RWO, classe `local-path`.
2. Quel est son statut ? Pourquoi ?
3. Crée un Deployment **`ecrivain`** (1 réplica, `busybox:1.37`) qui monte `donnees` sur `/data` et ajoute toutes les 10 secondes une ligne datée à `/data/journal.txt` (`while true; do date >> /data/journal.txt; sleep 10; done`).
4. Observe la PVC et le PV créé. Sur quel répertoire du nœud se trouvent les données ? (`kubectl get pv <nom> -o yaml`)

## Exercice 3 — Persistance

1. Supprime le Pod du Deployment `ecrivain`. Une fois le nouveau Pod démarré, vérifie que `journal.txt` contient toujours les anciennes lignes.
2. Ajoute un fichier **`/data/preuve.txt`** contenant `persistant` depuis le Pod, puis supprime encore le Pod et vérifie qu'il est toujours là.

## Exercice 4 — Provisionnement statique

1. Crée un PV **`pv-manuel`** de **100Mi**, RWO, politique **`Retain`**, `storageClassName: manuel`, de type `hostPath` sur `/tmp/pv-manuel` (type `DirectoryOrCreate`).
2. Crée une PVC **`pvc-manuelle`** qui se lie à ce PV (même classe, taille compatible).
3. Vérifie la liaison : quelle colonne de `kubectl get pv` le montre ?

## Exercice 5 — Fil rouge : PostgreSQL persistant

1. Applique `fil-rouge/08-volumes/` : PVC `postgres-data` et Deployment `postgres` modifié.
2. Crée une tâche dans l'interface, supprime le Pod PostgreSQL, et vérifie que la tâche existe toujours.
3. Question : que se passerait-il en passant le Deployment `postgres` à 2 réplicas ? Pourquoi ce n'est pas la bonne façon de répliquer une base ?
