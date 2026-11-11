# Mini-leçon — etcd

> Durée : 30 min.

## Le rôle d'etcd

**etcd** est la mémoire du cluster. Chaque objet Kubernetes (Pod, Secret, Deployment…) y est stocké sous forme de paire clé/valeur, par exemple sous la clé `/registry/pods/task-manager/frontend-7d9f…`. Seul l'**API server** lit et écrit dans etcd ; tous les autres composants passent par l'API.

Conséquence directe : **perdre etcd, c'est perdre le cluster** (les conteneurs continuent de tourner un temps, mais plus personne ne sait ce qu'ils devraient être). Les sauvegardes d'etcd sont la sauvegarde la plus importante d'un cluster.

## Comment etcd reste cohérent : Raft

etcd est une base **distribuée** : on la fait tourner sur plusieurs machines (3 ou 5 en général) qui s'accordent grâce à l'algorithme de consensus **Raft** :

- les membres élisent un **leader** ; toutes les écritures passent par lui ;
- une écriture n'est validée que lorsqu'une **majorité** (le *quorum*) l'a enregistrée ;
- si le leader tombe, les autres en élisent un nouveau.

| Membres | Quorum | Pannes tolérées |
|---|---|---|
| 1 | 1 | 0 |
| 3 | 2 | 1 |
| 5 | 3 | 2 |

C'est pourquoi on choisit un nombre **impair** : 4 membres ne tolèrent pas plus de pannes que 3.

## Le mécanisme « watch »

Les contrôleurs, le scheduler et les kubelets ne relisent pas tout en boucle : ils ouvrent une **surveillance** (*watch*) via l'API server, qui s'appuie sur la fonction watch d'etcd. Chaque modification d'objet leur est **poussée** quasi instantanément. C'est ce qui rend les boucles de réconciliation à la fois réactives et économes. Tu peux observer ce flux toi-même :

```bash
kubectl get pods -A --watch
```

## Et dans k3s ?

Par défaut, un serveur k3s unique n'utilise **pas** etcd mais **SQLite**, via une couche de traduction nommée **kine** qui présente une API compatible etcd à l'API server. C'est plus léger et parfait pour un nœud unique.

Pour un plan de contrôle **haute disponibilité** (3 serveurs), k3s embarque un vrai etcd :

```bash
# premier serveur
curl -sfL https://get.k3s.io | sh -s - server --cluster-init
# serveurs suivants
curl -sfL https://get.k3s.io | K3S_TOKEN=<jeton> sh -s - server --server https://<ip-serveur-1>:6443
```

kine permet aussi d'utiliser MySQL/MariaDB ou PostgreSQL comme datastore externe (`--datastore-endpoint`).

Pour savoir ce qu'utilise ton installation :

```bash
sudo ls /var/lib/rancher/k3s/server/db/
# state.db  → SQLite (via kine)
# etcd/     → etcd embarqué
```

## Sauvegarder et restaurer

Avec etcd embarqué, k3s prend des **snapshots** automatiques (toutes les 12 h par défaut) dans `/var/lib/rancher/k3s/server/db/snapshots/` :

```bash
sudo k3s etcd-snapshot save --name avant-mise-a-jour
sudo k3s etcd-snapshot list
# restauration (serveur arrêté) :
sudo k3s server --cluster-reset --cluster-reset-restore-path=<chemin-du-snapshot>
```

Avec SQLite, la sauvegarde consiste à copier le dossier `/var/lib/rancher/k3s/server/db/` ainsi que le jeton `/var/lib/rancher/k3s/server/token`, service arrêté.

Sur un cluster Kubernetes « classique », on utilise `etcdctl snapshot save` / `etcdutl snapshot restore`.

## Sécurité

etcd contient **tous les Secrets** du cluster. Par défaut, ils y sont seulement encodés en base64, pas chiffrés. En production, on active le **chiffrement au repos** (k3s : option `--secrets-encryption`) et on restreint strictement l'accès réseau à etcd (ports 2379-2380) au seul plan de contrôle.

## Vocabulaire

| Terme | Définition |
|---|---|
| **etcd** | Base clé/valeur distribuée et cohérente qui stocke l'état du cluster. |
| **Raft** | Algorithme de consensus utilisé par etcd pour rester cohérent entre plusieurs membres. |
| **Leader** | Membre etcd élu qui ordonne toutes les écritures. |
| **Quorum** | Majorité de membres nécessaire pour valider une écriture. |
| **Watch** | Abonnement aux modifications d'un ensemble de clés/objets. |
| **kine** | Couche de k3s qui émule l'API etcd au-dessus de SQLite, MySQL ou PostgreSQL. |
| **Snapshot** | Copie cohérente de la base etcd à un instant donné. |
| **Chiffrement au repos** | Chiffrement des données sur disque (ici, des Secrets dans etcd). |
