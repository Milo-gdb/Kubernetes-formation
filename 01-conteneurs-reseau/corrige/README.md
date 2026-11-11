# Corrigé TD 01

## Exercice 1

```bash
docker run -d --name td01-web -p 8081:80 nginx:1.30-alpine
curl -s http://localhost:8081 | grep title
docker logs td01-web
docker exec -it td01-web sh -c 'ps'   # quelques processus : nginx master + workers
```

Dans le conteneur, `ps` ne montre que les processus nginx (namespace PID). Sur l'hôte, `ps aux | grep nginx` montre ces mêmes processus, avec d'autres PID : c'est la même chose vue sous deux angles.

## Exercice 2

Fichiers : [`site/Dockerfile`](site/Dockerfile) et [`site/index.html`](site/index.html).

```bash
mkdir -p ~/formation-k8s/ch01/site && cd ~/formation-k8s/ch01/site
# copier ou écrire index.html et Dockerfile
docker build -t td01-site:v1 .
docker run -d --name td01-site -p 8082:80 td01-site:v1
curl -s http://localhost:8082
```

## Exercice 3

Configuration : [`proxy/default.conf`](proxy/default.conf).

```bash
docker network create td01-net
docker run -d --name td01-backend --network td01-net traefik/whoami:v1.12.0
mkdir -p ~/formation-k8s/ch01/proxy   # y placer default.conf
docker run -d --name td01-proxy --network td01-net -p 8083:80 \
  -v ~/formation-k8s/ch01/proxy/default.conf:/etc/nginx/conf.d/default.conf:ro \
  nginx:1.30-alpine
curl -s http://localhost:8083
```

La réponse de whoami contient `X-Real-Ip: 172.x.x.1` : le backend connaît l'IP du client grâce à l'en-tête ajouté par le proxy. Le nom `td01-backend` est résolu par le DNS intégré au réseau utilisateur Docker.

Si le backend est supprimé, nginx renvoie **502 Bad Gateway** (ou refuse de démarrer s'il ne peut pas résoudre le nom au lancement).

## Exercice 4

```bash
ps aux | grep -o -- '--containerd=[^ ]*'          # trouver la socket utilisée par dockerd
sudo ctr --address /run/containerd/containerd.sock -n moby containers list
docker inspect -f '{{.Id}}' td01-web              # même identifiant !
sudo ctr --address /run/containerd/containerd.sock -n moby containers list -q \
  | grep "$(docker inspect -f '{{.Id}}' td01-web)" > ~/formation-k8s/ch01/containerd-id.txt
```

Docker range ses conteneurs dans le namespace containerd `moby`, avec le même identifiant que celui affiché par `docker inspect`.
