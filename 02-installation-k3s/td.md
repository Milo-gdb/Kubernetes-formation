# TD 02 — Installer k3s et prendre en main kubectl

> Vérification : `./02-installation-k3s/verifier.sh`

## Exercice 1 — Installer k3s

Installe k3s sur ta machine avec le script officiel (voir la leçon), **avec ses composants par défaut** (Traefik, ServiceLB, local-path, metrics-server : nous les utiliserons tous).

Vérifie que le service `k3s` est actif et que ton nœud est `Ready`.

## Exercice 2 — kubectl sans sudo

Configure ton utilisateur pour que `kubectl get nodes` fonctionne **sans `sudo`**, avec un kubeconfig dans `~/.kube/config` protégé correctement.

## Exercice 3 — Explorer le cluster

1. Liste tous les Pods de tous les namespaces. Quels sont les composants système présents ?
2. Affiche la version de Kubernetes de ton nœud ainsi que son adresse IP interne.
3. Affiche la consommation CPU/mémoire de ton nœud.
4. Combien de types de ressources (`api-resources`) ton cluster connaît-il ?

## Exercice 4 — Labels

Ajoute le label **`formation=kubernetes`** à ton nœud, puis affiche la liste des nœuds filtrée sur ce label.

## Exercice 5 — Observer la réconciliation

1. Dans un terminal, lance `kubectl get pods -n kube-system -w`.
2. Dans un second terminal, supprime le Pod CoreDNS : `kubectl delete pod -n kube-system -l k8s-app=kube-dns`.
3. Que se passe-t-il dans le premier terminal ? Qui a recréé le Pod, et pourquoi ?

## Exercice 6 — Le datastore (lien avec la [mini-leçon etcd](mini-lecon-etcd.md))

Détermine si ton k3s utilise **SQLite** ou **etcd** et écris le mot `sqlite` ou `etcd` dans `~/formation-k8s/ch02/datastore.txt`.

## Pour aller plus loin

- Lis `kubectl get node <nom> -o yaml` : repère `status.capacity`, `status.allocatable` et `status.conditions`.
- Ajoute un second nœud (une autre VM) : `curl -sfL https://get.k3s.io | K3S_URL=https://<ip>:6443 K3S_TOKEN=<contenu de /var/lib/rancher/k3s/server/node-token> sh -`.
