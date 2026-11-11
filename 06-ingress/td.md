# TD 06 — Ingress

> Namespace de travail : **`td-06`**. Manifestes dans `~/formation-k8s/ch06/`.
> Vérification : `./06-ingress/verifier.sh`

## Exercice 1 — Le contrôleur

1. Trouve le contrôleur Ingress installé dans ton cluster : dans quel namespace tourne-t-il ? Quelle IngressClass expose-t-il ?
2. Par quel Service reçoit-il le trafic et sur quelle IP ?

## Exercice 2 — Routage par chemin

1. Crée deux Deployments + Services ClusterIP **`app-a`** et **`app-b`** (image `traefik/whoami:v1.12.0`, port 80). Passe à chacun l'argument `--name=app-a` (resp. `app-b`) pour qu'il affiche son nom dans ses réponses.
2. Crée un Ingress **`chemins`** pour l'hôte **`demo.local`** : `/a` → `app-a`, `/b` → `app-b`.
3. Teste avec `curl --resolve demo.local:80:<IP> http://demo.local/a` : la ligne `Name:` doit indiquer `app-a`. Regarde aussi la ligne `GET` : quel chemin reçoit le backend ?

## Exercice 3 — Routage par hôte

Crée un Ingress **`hotes`** : `a.demo.local` → `app-a`, `b.demo.local` → `app-b` (chemin `/`).

Que renvoie Traefik pour un hôte inconnu (`c.demo.local`) ?

## Exercice 4 — Fil rouge : task-manager.local

1. Crée l'Ingress **`task-manager`** dans le namespace `task-manager` : `task-manager.local` → `frontend:80` et `api.task-manager.local` → `api:3000`.
2. Ajoute ces deux noms dans le `/etc/hosts` de ta machine, pointant vers l'IP du contrôleur.
3. Ouvre `http://task-manager.local` dans un navigateur, et `http://api.task-manager.local/` avec curl.

Référence : `fil-rouge/06-ingress/50-ingress.yaml`.

## Pour aller plus loin

- Ajoute un Middleware Traefik `stripPrefix` pour que `app-a` reçoive `/` au lieu de `/a` (voir la [mini-leçon](mini-lecon-nginx-ingress.md)).
- Crée un certificat auto-signé (`openssl req -x509 ...`), un Secret TLS (`kubectl create secret tls`) et sers `https://demo.local`.
