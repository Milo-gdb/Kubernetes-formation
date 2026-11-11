# Chapitre 02 — Architecture de Kubernetes et installation de k3s

> **Objectifs** : comprendre les composants d'un cluster et leur rôle, installer k3s, configurer `kubectl` et faire ses premiers pas en ligne de commande.
>
> **Durée estimée** : 2 h 30 — **Mini-leçon associée** : [etcd](mini-lecon-etcd.md)

---

## 1. Ce que Kubernetes apporte

Lancer un conteneur sur une machine, Docker le fait très bien. Mais en production, les questions s'accumulent : que faire si la machine tombe ? Comment lancer 10 copies et répartir le trafic ? Comment mettre à jour sans coupure ? Où placer chaque conteneur pour ne saturer aucune machine ?

Kubernetes est un **orchestrateur** : tu lui décris l'**état désiré** (« je veux 3 copies de ce conteneur, joignables sur ce nom ») et il se charge en continu de faire correspondre la réalité à cette description. Ce modèle **déclaratif** est le cœur de tout ce qui suit.

```text
      tu déclares                  Kubernetes observe et corrige en boucle
┌──────────────────┐        ┌────────────────────────────────────────────┐
│ replicas: 3      │ ─────► │ observé: 2 ─► écart ! ─► créer 1 pod ─► 3 ✔ │
└──────────────────┘        └────────────────────────────────────────────┘
```

Cette **boucle de réconciliation** est exécutée par des **contrôleurs**. Retiens ce mot : il revient partout.

## 2. Architecture d'un cluster

Un cluster se compose d'un **plan de contrôle** (control plane), qui décide, et de **nœuds de travail** (workers), qui exécutent.

```text
┌──────────────────────────── Plan de contrôle ────────────────────────────┐
│                                                                           │
│   kubectl ──► kube-apiserver ◄──► etcd (base clé/valeur : tout l'état)    │
│                  ▲      ▲                                                 │
│                  │      └── kube-scheduler   (choisit un nœud par Pod)     │
│                  └───────── kube-controller-manager (boucles de contrôle) │
└──────────────────┬────────────────────────────────────────────────────────┘
                   │  (tout passe par l'API)
     ┌─────────────┴────────────┐               ┌──────────────────────────┐
     │ Nœud 1                   │               │ Nœud 2                   │
     │  kubelet ──► containerd  │               │  kubelet ──► containerd  │
     │  kube-proxy              │               │  kube-proxy              │
     │  [pod] [pod] [pod]       │               │  [pod] [pod]             │
     └──────────────────────────┘               └──────────────────────────┘
```

| Composant | Rôle |
|---|---|
| **kube-apiserver** | Porte d'entrée unique. Valide, authentifie, stocke dans etcd. Tous les composants passent par lui, aucun ne se parle directement. |
| **etcd** | Base de données clé/valeur distribuée qui contient l'état complet du cluster. → [mini-leçon](mini-lecon-etcd.md) |
| **kube-scheduler** | Pour chaque nouveau Pod sans nœud, choisit le nœud le plus adapté (ressources, contraintes…). |
| **kube-controller-manager** | Fait tourner les contrôleurs : Deployment, ReplicaSet, Node, Job, endpoints… |
| **kubelet** | Agent présent sur chaque nœud : lit les Pods qui lui sont attribués et demande au runtime de les lancer, puis remonte leur état. |
| **kube-proxy** | Programme les règles réseau (iptables/nftables/IPVS) qui implémentent les Services. |
| **Runtime (containerd)** | Exécute réellement les conteneurs (chapitre 01). |
| **CoreDNS** | DNS interne du cluster (s'exécute lui-même dans des Pods). |
| **CNI (Flannel dans k3s)** | Plugin qui donne une IP à chaque Pod et relie les nœuds entre eux. |

### Exemple : le trajet d'un `kubectl apply`

1. `kubectl` envoie le manifeste à l'**API server** (HTTPS, port 6443).
2. L'API server authentifie, valide et **enregistre l'objet dans etcd**. C'est tout : il ne lance rien lui-même.
3. Le **contrôleur** concerné (par ex. Deployment) voit le nouvel objet et crée les objets dérivés (ReplicaSet, puis Pods).
4. Le **scheduler** voit des Pods sans nœud et leur en attribue un.
5. Le **kubelet** du nœud choisi voit qu'un Pod lui est attribué et le fait démarrer par **containerd**.
6. Le kubelet remonte le statut (`Running`) à l'API server, qui l'écrit dans etcd.

## 3. k3s : un Kubernetes complet et léger

[k3s](https://k3s.io) est une **distribution Kubernetes certifiée** (projet CNCF) conçue pour être légère : un seul binaire d'environ 70 Mo qui contient tous les composants ci-dessus. Il est idéal pour apprendre, pour l'edge et l'IoT, et convient aussi à de vrais petits clusters.

Ce qu'il apporte « clé en main » :

| Fonction | Composant fourni par k3s |
|---|---|
| Runtime | containerd |
| Réseau des Pods | Flannel (VXLAN) |
| DNS | CoreDNS |
| Contrôleur Ingress | Traefik |
| Load balancer pour Services `LoadBalancer` | ServiceLB (ex-Klipper) |
| Stockage persistant | local-path-provisioner |
| Métriques (`kubectl top`) | metrics-server |
| Base de données | SQLite par défaut, etcd embarqué en mode haute disponibilité |

!!! info "Et les autres options ?"
    minikube, kind, MicroK8s ou k0s sont d'autres façons d'avoir un cluster local. Tout ce que tu apprendras ici fonctionne sur n'importe quel Kubernetes conforme : seuls les composants « fournis » (Ingress, stockage) diffèrent.

## 4. Installer k3s

### 4.1 Installation

Sur une machine Linux (VM ou physique), avec un utilisateur disposant de `sudo` :

```bash
curl -sfL https://get.k3s.io | sh -
```

Le script télécharge le binaire, installe un service systemd `k3s` et le démarre. Quelques secondes plus tard :

```bash
sudo systemctl status k3s          # le service doit être "active (running)"
sudo k3s kubectl get nodes         # ton nœud doit être "Ready"
```

!!! tip "Bonnes pratiques"
    - Lis toujours un script avant de le passer à `sh` : `curl -sfL https://get.k3s.io -o install-k3s.sh && less install-k3s.sh`.
    - Pour figer la version : `curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=<version> sh -`.
    - Les options du serveur se passent via `INSTALL_K3S_EXEC` ou, plus proprement, dans `/etc/rancher/k3s/config.yaml`.

### 4.2 Configurer `kubectl` pour ton utilisateur

k3s écrit un kubeconfig administrateur dans `/etc/rancher/k3s/k3s.yaml`, lisible par root uniquement. Copie-le dans ton dossier personnel :

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$(id -u):$(id -g)" ~/.kube/config
chmod 600 ~/.kube/config
kubectl get nodes      # fonctionne désormais sans sudo
```

k3s installe un lien `kubectl` vers son binaire. Si tu utilises `kubectl` depuis une **autre machine**, copie ce fichier et remplace `127.0.0.1` par l'IP du serveur dans la ligne `server:`.

### 4.3 Le kubeconfig expliqué

```yaml
apiVersion: v1
kind: Config
clusters:                       # OÙ : l'adresse de l'API et son certificat d'autorité
  - name: default
    cluster:
      server: https://127.0.0.1:6443
      certificate-authority-data: LS0t...
users:                          # QUI : les identifiants (ici un certificat client)
  - name: default
    user:
      client-certificate-data: LS0t...
      client-key-data: LS0t...
contexts:                       # un contexte = un cluster + un utilisateur (+ namespace)
  - name: default
    context:
      cluster: default
      user: default
current-context: default        # le contexte utilisé par défaut
```

```bash
kubectl config get-contexts
kubectl config current-context
kubectl config set-context --current --namespace=task-manager   # changer de namespace par défaut
```

### 4.4 Désinstaller

```bash
/usr/local/bin/k3s-uninstall.sh
```

## 5. Premiers pas avec kubectl

`kubectl` suit toujours la même grammaire : **`kubectl <verbe> <type> [<nom>] [options]`**.

| Commande | Effet |
|---|---|
| `kubectl get nodes -o wide` | lister les nœuds, avec IP et version |
| `kubectl get pods -A` | lister les Pods de **tous** les namespaces |
| `kubectl describe node <nom>` | détails lisibles + événements récents |
| `kubectl get pod <nom> -o yaml` | l'objet complet tel que stocké dans etcd |
| `kubectl explain pod.spec.containers` | documentation intégrée des champs |
| `kubectl api-resources` | tous les types d'objets connus du cluster |
| `kubectl label node <nom> cle=valeur` | ajouter un label |
| `kubectl top nodes` | consommation CPU/RAM (metrics-server) |
| `kubectl get events -A --sort-by=.lastTimestamp` | journal des événements du cluster |

!!! tip "Gagner du temps"
    ```bash
    source <(kubectl completion bash)                    # autocomplétion
    echo 'source <(kubectl completion bash)' >> ~/.bashrc
    alias k=kubectl && complete -o default -F __start_kubectl k
    ```

### Labels

Un **label** est une paire clé/valeur attachée à n'importe quel objet. Kubernetes s'en sert partout pour **sélectionner** des objets : un Service trouve ses Pods par labels, un Deployment reconnaît les siens par labels, et tu peux filtrer avec `-l` :

```bash
kubectl get pods -A -l k8s-app=kube-dns
```

## 6. Ce qui tourne déjà dans ton cluster

```bash
kubectl get pods -n kube-system
```

Tu y trouveras `coredns`, `traefik`, `svclb-traefik`, `local-path-provisioner`, `metrics-server`. Tu remarqueras que l'API server, le scheduler et etcd n'apparaissent **pas** comme Pods : dans k3s, ils tournent à l'intérieur du processus `k3s server` lui-même.

---

## Vocabulaire

| Terme | Définition |
|---|---|
| **Cluster** | Ensemble de machines gérées par un même plan de contrôle Kubernetes. |
| **Nœud (node)** | Machine (VM ou physique) du cluster qui exécute des Pods. |
| **Plan de contrôle** | Composants qui prennent les décisions : API server, etcd, scheduler, controller-manager. |
| **API server** | Point d'entrée REST unique du cluster. |
| **Contrôleur** | Boucle qui compare l'état désiré et l'état observé et agit pour les rapprocher. |
| **Réconciliation** | Action continue de faire converger l'observé vers le désiré. |
| **Déclaratif** | On décrit le résultat voulu, pas les étapes pour y arriver. |
| **kubelet** | Agent de chaque nœud qui fait tourner les Pods qui lui sont attribués. |
| **kubeconfig** | Fichier qui indique à kubectl où est le cluster et avec quelle identité s'y connecter. |
| **Contexte** | Combinaison cluster + utilisateur + namespace dans un kubeconfig. |
| **Label** | Paire clé/valeur attachée à un objet, utilisée pour sélectionner des objets. |
| **CNI** | Container Network Interface : standard des plugins réseau des Pods. |
| **Distribution** | Kubernetes packagé avec des choix de composants (k3s, RKE2, OpenShift…). |
