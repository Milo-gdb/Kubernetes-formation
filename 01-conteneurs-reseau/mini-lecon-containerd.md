# Mini-leçon — containerd

> Durée : 30 min. À lire après la leçon du chapitre 01 ; les commandes `crictl` seront utilisables après l'installation de k3s (chapitre 02).

## Pourquoi s'y intéresser ?

Sur un nœud k3s, **il n'y a pas de Docker** : ce sont **containerd** et **runc** qui font tourner tes Pods. Quand `kubectl` ne suffit plus (le kubelet ne répond plus, une image refuse de se télécharger…), il faut savoir interroger containerd directement.

## Architecture

```text
kubelet ──(gRPC CRI)──► containerd ──► containerd-shim-runc-v2 ──► runc ──► conteneur
                           │
                           ├─ service images   (téléchargement, couches, snapshots)
                           ├─ service conteneurs (métadonnées)
                           └─ service tâches   (processus en cours)
```

- containerd est un **démon** unique par machine, exposé sur une socket Unix.
- Pour chaque conteneur, il lance un petit processus **shim** qui reste parent du conteneur : on peut redémarrer containerd sans tuer les conteneurs.
- containerd range ses objets dans des **namespaces containerd** (sans rapport avec ceux de Linux ou de Kubernetes) : Docker utilise le namespace `moby`, Kubernetes le namespace `k8s.io`.

## Trois clients en ligne de commande

| Outil | Public | Points forts |
|---|---|---|
| `ctr` | développeurs de containerd | Livré avec containerd, très bas niveau, pas pensé pour l'usage quotidien. |
| `crictl` | administrateurs Kubernetes | Parle CRI comme le kubelet : voit les **Pods** et les conteneurs comme Kubernetes. |
| `nerdctl` | utilisateurs venant de Docker | Syntaxe compatible Docker (`nerdctl run -p 8080:80 ...`). |

## Sur une machine avec Docker

Docker s'appuie lui-même sur containerd. Tu peux le constater :

```bash
docker run -d --name demo nginx:1.30-alpine
sudo ctr --address /run/containerd/containerd.sock namespaces list   # → moby
sudo ctr --address /run/containerd/containerd.sock -n moby containers list
# L'identifiant affiché est le même que celui de : docker inspect -f '{{.Id}}' demo
```

!!! note
    Selon les versions, Docker peut utiliser une socket différente (`/var/run/docker/containerd/containerd.sock`). Utilise `ps aux | grep containerd` pour retrouver l'option `--address`.

## Sur un nœud k3s

k3s embarque son containerd (socket `/run/k3s/containerd/containerd.sock`) et fournit `crictl` et `ctr` en sous-commandes :

```bash
sudo k3s crictl pods                 # les Pods vus par le runtime
sudo k3s crictl ps                   # les conteneurs en cours
sudo k3s crictl images               # les images présentes sur le nœud
sudo k3s crictl logs <id-conteneur>  # journaux, même si l'API Kubernetes est indisponible
sudo k3s crictl inspect <id>         # détails bas niveau (PID, montages, cgroups)
sudo k3s ctr -n k8s.io images ls     # vue ctr du namespace Kubernetes
```

### Importer une image sans registre

Une image construite avec Docker n'est pas visible par le containerd de k3s (ce sont deux magasins d'images distincts). Pour la tester sans registre :

```bash
docker save mon-image:v1 -o mon-image.tar
sudo k3s ctr images import mon-image.tar
```

Il faut alors utiliser `imagePullPolicy: IfNotPresent` (ou `Never`) dans le Pod pour que Kubernetes ne tente pas de la télécharger.

## Configuration

- containerd standard : `/etc/containerd/config.toml`
- k3s : généré dans `/var/lib/rancher/k3s/agent/etc/containerd/config.toml` ; on le personnalise via un **modèle** (`config.toml.tmpl`) ou, pour les registres privés et miroirs, via `/etc/rancher/k3s/registries.yaml`.

## Vocabulaire

| Terme | Définition |
|---|---|
| **containerd** | Démon qui gère images, conteneurs et processus sur une machine. |
| **Shim** | Petit processus intermédiaire, parent d'un conteneur, qui le découple de containerd. |
| **Namespace containerd** | Espace de rangement logique des objets containerd (`moby`, `k8s.io`). |
| **crictl** | Client CRI pour inspecter le runtime d'un nœud Kubernetes. |
| **ctr** | Client bas niveau livré avec containerd. |
| **nerdctl** | Client compatible avec la syntaxe Docker pour containerd. |
| **Snapshotter** | Composant de containerd qui assemble les couches d'image en système de fichiers (overlayfs…). |
