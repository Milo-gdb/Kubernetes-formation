# Corrigé TD 02

## Exercice 1

```bash
curl -sfL https://get.k3s.io | sh -
sudo systemctl is-active k3s        # active
sudo k3s kubectl get nodes          # STATUS Ready
```

## Exercice 2

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$(id -u):$(id -g)" ~/.kube/config
chmod 600 ~/.kube/config
kubectl get nodes
```

Variante : installer k3s avec `--write-kubeconfig-mode 644` rend `/etc/rancher/k3s/k3s.yaml` lisible par tous — pratique sur une VM de test, **à éviter** sur une machine partagée.

## Exercice 3

```bash
kubectl get pods -A
kubectl get nodes -o wide                  # colonnes VERSION et INTERNAL-IP
kubectl top node                           # peut demander ~1 min après l'installation
kubectl api-resources --no-headers | wc -l
```

Composants système attendus : `coredns`, `local-path-provisioner`, `metrics-server`, `traefik`, `svclb-traefik-…` (et des Pods `helm-install-…` terminés, qui ont servi à installer Traefik).

## Exercice 4

```bash
kubectl label node "$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')" formation=kubernetes
kubectl get nodes -l formation=kubernetes
kubectl get nodes --show-labels
```

## Exercice 5

Le Pod supprimé passe en `Terminating`, et **un nouveau Pod avec un autre nom** apparaît aussitôt. CoreDNS est géré par un **Deployment** : son ReplicaSet constate qu'il manque une réplique par rapport à l'état désiré et en recrée une. C'est la boucle de réconciliation en action (chapitre 04).

## Exercice 6

```bash
sudo ls /var/lib/rancher/k3s/server/db/
mkdir -p ~/formation-k8s/ch02
echo sqlite > ~/formation-k8s/ch02/datastore.txt   # si state.db est présent
```

Une installation mono-serveur par défaut utilise **SQLite** via kine. Le dossier `etcd/` n'existe que si k3s a été lancé avec `--cluster-init` (ou rejoint un cluster HA).
