# TD 01 — Conteneurs et reverse proxy

> Prérequis : Docker installé (`docker run hello-world` fonctionne sans erreur ; ajoute ton utilisateur au groupe `docker` si besoin).
> Travaille dans `~/formation-k8s/ch01/`. Vérification : `./01-conteneurs-reseau/verifier.sh`

## Exercice 1 — Premier conteneur

Lance un conteneur nommé **`td01-web`** à partir de l'image `nginx:1.30-alpine`, en arrière-plan, accessible sur le **port 8081** de ta machine. Ouvre `http://localhost:8081`.

Puis explore : affiche ses journaux, ouvre un shell à l'intérieur, liste les processus qui y tournent. Combien y en a-t-il ? Compare avec `ps aux` sur l'hôte.

## Exercice 2 — Construire ta propre image

1. Dans `~/formation-k8s/ch01/site/`, crée un `index.html` contenant le texte **`Ma première image`**.
2. Écris un `Dockerfile` basé sur `nginx:1.30-alpine` qui copie cette page à la place de la page par défaut.
3. Construis l'image **`td01-site:v1`**.
4. Lance-la dans un conteneur **`td01-site`** accessible sur le **port 8082**.

## Exercice 3 — Reverse proxy nginx

On veut reproduire le schéma « un proxy devant une application » :

1. Crée un réseau Docker **`td01-net`**.
2. Lance un conteneur **`td01-backend`** (image `traefik/whoami:v1.12.0`) sur ce réseau, **sans publier de port** : il ne doit être joignable que via le proxy.
3. Écris une configuration nginx `~/formation-k8s/ch01/proxy/default.conf` qui relaie toutes les requêtes vers le backend **et transmet l'IP réelle du client** dans l'en-tête `X-Real-IP`.
4. Lance un conteneur **`td01-proxy`** (`nginx:1.30-alpine`) sur le même réseau, avec ta configuration montée dans `/etc/nginx/conf.d/`, publié sur le **port 8083**.

`curl http://localhost:8083` doit afficher la réponse de whoami (qui liste les en-têtes reçus).

## Exercice 4 — Sous le capot : containerd

Docker délègue l'exécution à containerd. Retrouve le conteneur `td01-web` **avec l'outil `ctr`** (voir la [mini-leçon](mini-lecon-containerd.md)) et écris son **identifiant complet**, tel que containerd le connaît, dans `~/formation-k8s/ch01/containerd-id.txt`.

## Pour aller plus loin

- Ajoute un second backend et fais du **routage par chemin** : `/a` → backend A, `/b` → backend B.
- Que se passe-t-il pour le proxy si tu supprimes `td01-backend` ? Quel code HTTP obtiens-tu ? (indice : tu le recroiseras souvent).

## Nettoyage (après validation)

```bash
docker rm -f td01-web td01-site td01-backend td01-proxy && docker network rm td01-net
```
