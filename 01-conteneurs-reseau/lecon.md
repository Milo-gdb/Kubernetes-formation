# Chapitre 01 — Conteneurs, Docker/containerd et reverse proxy nginx

> **Objectifs** : comprendre ce qu'est réellement un conteneur, savoir construire et lancer une image, connaître la place de containerd, et maîtriser le principe du reverse proxy avec nginx — la base de l'Ingress.
>
> **Durée estimée** : 3 h — **Mini-leçon associée** : [containerd](mini-lecon-containerd.md)

---

## 1. Qu'est-ce qu'un conteneur ?

Un conteneur n'est **pas** une petite machine virtuelle. C'est un **processus Linux ordinaire** que le noyau isole grâce à deux mécanismes :

- les **namespaces** : ils limitent ce que le processus **voit** (ses propres PID, son propre réseau, son propre système de fichiers, son propre nom d'hôte…) ;
- les **cgroups** (control groups) : ils limitent ce que le processus **consomme** (CPU, mémoire, I/O).

```text
   Machine virtuelle                       Conteneurs
┌──────────┐┌──────────┐            ┌──────────┐┌──────────┐
│  App A   ││  App B   │            │  App A   ││  App B   │
│ Libs     ││ Libs     │            │ Libs     ││ Libs     │
│ Noyau    ││ Noyau    │            └──────────┘└──────────┘
└──────────┘└──────────┘            ┌────────────────────────┐
┌────────────────────────┐          │  Noyau Linux partagé    │
│     Hyperviseur        │          │  (namespaces + cgroups) │
└────────────────────────┘          └────────────────────────┘
```

Conséquences pratiques :

- un conteneur démarre en **millisecondes** (pas de noyau à booter) ;
- tous les conteneurs d'une machine **partagent le même noyau** : un conteneur Linux ne tourne que sur un noyau Linux ;
- l'isolation est plus faible qu'une VM : on ne fait pas tourner de code hostile sans précautions supplémentaires.

## 2. Images et registres

Une **image** est un modèle en lecture seule : un empilement de **couches** (layers) de système de fichiers, plus des métadonnées (commande de démarrage, ports, variables). Un conteneur, c'est une image + une fine couche inscriptible + un processus en cours d'exécution.

Les images sont stockées dans des **registres** (Docker Hub, GitHub Container Registry, Quay, un registre privé…). Une référence d'image se lit ainsi :

```text
docker.io/library/nginx:1.30-alpine
└───┬───┘ └──┬──┘ └─┬─┘ └────┬────┘
 registre  projet  nom      tag
```

!!! warning "Évite le tag `latest`"
    `latest` n'est qu'une étiquette mobile : demain elle désignera peut-être une autre version. En production comme dans cette formation, on **épingle une version** (`nginx:1.30-alpine`) pour que les déploiements soient reproductibles.

### Construire une image : le Dockerfile

```dockerfile
FROM nginx:1.30-alpine                 # image de base
COPY index.html /usr/share/nginx/html/ # ajoute une couche avec notre fichier
EXPOSE 80                              # documentation : le port écouté
# CMD hérité de l'image de base : nginx -g 'daemon off;'
```

```bash
docker build -t mon-site:v1 .      # construire
docker images                      # lister les images locales
```

Chaque instruction crée une couche ; les couches inchangées sont réutilisées depuis le cache, d'où l'intérêt de placer en dernier ce qui change le plus souvent.

## 3. Lancer et inspecter des conteneurs

| Action | Commande |
|---|---|
| Lancer en arrière-plan, nommé, port publié | `docker run -d --name web -p 8081:80 nginx:1.30-alpine` |
| Lister (actifs / tous) | `docker ps` / `docker ps -a` |
| Journaux | `docker logs -f web` |
| Ouvrir un shell dedans | `docker exec -it web sh` |
| Détails (IP, montages…) | `docker inspect web` |
| Arrêter / supprimer | `docker stop web` / `docker rm -f web` |

`-p 8081:80` signifie : « le port **8081 de l'hôte** redirige vers le port **80 du conteneur** ». Tu retrouveras exactement cette idée avec `kubectl port-forward` et les Services NodePort.

### Réseaux Docker

Par défaut, chaque conteneur reçoit une IP privée sur un pont (`bridge`). Sur un **réseau utilisateur** (`docker network create mon-reseau`), les conteneurs se trouvent **par leur nom** grâce à un DNS intégré :

```bash
docker network create td01-net
docker run -d --name backend --network td01-net traefik/whoami:v1.12.0
docker run --rm --network td01-net curlimages/curl:8.23.0 -s http://backend
```

C'est le même principe que les noms DNS des Services Kubernetes.

## 4. Docker, containerd, runc : qui fait quoi ?

« Docker » désigne à la fois une entreprise, un outil en ligne de commande et un ensemble de composants. Sous le capot, la chaîne est la suivante :

```text
docker CLI ──► dockerd ──► containerd ──► containerd-shim ──► runc ──► processus
                              ▲
kubelet (Kubernetes) ── CRI ──┘
```

- **runc** crée concrètement le processus isolé (namespaces, cgroups) selon la norme **OCI**, puis s'efface ;
- **containerd** gère le cycle de vie des conteneurs et des images sur une machine ;
- **dockerd** ajoute l'expérience développeur (build, réseaux, volumes, compose…).

Kubernetes n'a **pas besoin de Docker** : le kubelet parle directement à containerd via l'interface **CRI**. Depuis Kubernetes 1.24, le pont « dockershim » a d'ailleurs été retiré. k3s embarque son propre containerd. Les images construites avec Docker restent parfaitement compatibles, puisque toutes respectent le format OCI.

👉 Détails dans la [mini-leçon containerd](mini-lecon-containerd.md).

## 5. Le reverse proxy avec nginx

### 5.1 Le principe

Un **reverse proxy** est un serveur placé **devant** une ou plusieurs applications. Le client ne parle qu'au proxy, qui relaie la requête vers la bonne application (le *backend* ou *upstream*) et renvoie la réponse.

```text
                     ┌──────────────────────┐
navigateur ──HTTP──► │   nginx (port 80)    │──► api:3000      (si chemin /api/)
                     │   reverse proxy      │──► frontend:80   (sinon)
                     └──────────────────────┘
```

Il sert à : publier plusieurs applications derrière une seule IP/port, terminer le TLS (HTTPS), répartir la charge, mettre en cache, ajouter des en-têtes, filtrer…

### 5.2 Une configuration nginx commentée

```nginx
server {
    listen 80;                         # port d'écoute
    server_name exemple.local;         # nom d'hôte concerné (en-tête Host)

    location / {                       # toute requête...
        proxy_pass http://backend:80;  # ...est relayée vers "backend"
        proxy_set_header Host $host;                   # conserve le Host d'origine
        proxy_set_header X-Real-IP $remote_addr;       # IP réelle du client
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

Points clés :

- **`server_name`** permet d'héberger plusieurs sites sur la même IP : nginx choisit le bloc `server` selon l'en-tête `Host`. C'est le **routage par hôte**.
- **`location`** choisit le traitement selon le **chemin** de l'URL. C'est le **routage par chemin**.
- **`proxy_pass http://api:3000/;`** — attention au `/` final : avec lui, le préfixe de la `location` est retiré (`/api/tasks` → `/tasks`) ; sans lui, le chemin est transmis tel quel.
- Sans les en-têtes `X-Forwarded-*`, l'application ne verrait que l'IP du proxy.

### 5.3 Le lien avec Kubernetes

Retiens bien ce schéma : au chapitre 06, l'**Ingress** sera exactement un reverse proxy dont on décrit les règles (hôtes, chemins, backends) en YAML, et qu'un **contrôleur** (Traefik, nginx…) transforme en configuration réelle. Et au chapitre 07, le frontend du fil rouge utilisera lui-même nginx en reverse proxy vers l'API.

---

## Vocabulaire

| Terme | Définition |
|---|---|
| **Conteneur** | Processus isolé par les namespaces et limité par les cgroups du noyau. |
| **Namespace (Linux)** | Mécanisme du noyau qui restreint la vue d'un processus (PID, réseau, montages…). Ne pas confondre avec le namespace Kubernetes. |
| **cgroup** | Mécanisme du noyau qui limite les ressources consommées par un groupe de processus. |
| **Image** | Modèle en lecture seule, composé de couches, servant à créer des conteneurs. |
| **Couche (layer)** | Différence de système de fichiers produite par une instruction du Dockerfile. |
| **Registre** | Serveur qui stocke et distribue des images. |
| **Tag** | Étiquette lisible désignant une version d'image. |
| **OCI** | Open Container Initiative : normes communes pour les images et les runtimes. |
| **runc** | Runtime bas niveau qui crée le processus conteneurisé. |
| **containerd** | Runtime de haut niveau qui gère images et conteneurs ; utilisé par k3s. |
| **CRI** | Container Runtime Interface : API entre le kubelet et le runtime. |
| **Reverse proxy** | Serveur qui reçoit les requêtes des clients et les relaie vers des applications internes. |
| **Upstream / backend** | Application vers laquelle le proxy relaie les requêtes. |
| **Routage par hôte / par chemin** | Choix du backend selon l'en-tête `Host` / selon le chemin de l'URL. |
