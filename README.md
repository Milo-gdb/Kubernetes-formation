# Formation Kubernetes

Formation **complète et en français** pour apprendre Kubernetes de façon progressive et pratique : des bases Linux et réseau jusqu'à Helm, sur un vrai cluster **k3s**, avec une application fil rouge, des TD corrigés et des scripts qui vérifient ton travail.

Site de la formation : **<https://milo-gdb.github.io/Kubernetes-formation/>** (généré avec MkDocs Material, voir plus bas).

## Organisation

Chaque chapitre contient :

| Fichier | Contenu |
|---|---|
| `lecon.md` | le cours, terminé par une section **Vocabulaire** |
| `td.md` | les exercices pratiques |
| `corrige/` | les manifestes de solution et leurs explications |
| `verifier.sh` | un script qui contrôle l'état de ton cluster et affiche ✅/❌ par exercice, avec un indice en cas d'échec |

Les cours sont rédigés pour cette formation : ils s'inspirent de la documentation officielle (kubernetes.io), qu'il reste utile de consulter, sans la recopier.

## Table des matières

### Fondations

| # | Chapitre | Contenu |
|---|---|---|
| 00 | [Prérequis](00-prerequis/lecon.md) | Linux, shell, YAML, processus et services |
| 01 | [Conteneurs et réseau](01-conteneurs-reseau/lecon.md) · [mini-leçon containerd](01-conteneurs-reseau/mini-lecon-containerd.md) | images, Docker/containerd, réseaux, DNS, nginx en reverse proxy |
| 02 | [Installation de k3s](02-installation-k3s/lecon.md) · [mini-leçon etcd](02-installation-k3s/mini-lecon-etcd.md) | architecture, installation de k3s, kubectl, kubeconfig |

### Objets de base

| # | Chapitre | Fil rouge |
|---|---|---|
| 03 | [Pods](03-pods/lecon.md) | le frontend dans un Pod |
| 04 | [Deployments](04-deployments/lecon.md) | frontend, API, PostgreSQL en Deployments |
| 05 | [Services](05-services/lecon.md) | découverte par DNS |
| 06 | [Ingress](06-ingress/lecon.md) · [mini-leçon NGINX Ingress](06-ingress/mini-lecon-nginx-ingress.md) | `task-manager.local` |
| 07 | [ConfigMaps et Secrets](07-config-secrets/lecon.md) | configuration et identifiants externalisés |
| 08 | [Volumes](08-volumes/lecon.md) | données PostgreSQL persistantes |

### Vers la production

| # | Chapitre | Fil rouge |
|---|---|---|
| 09 | [Sondes, ressources, autoscaling](09-sondes-ressources-autoscaling/lecon.md) | sondes, requests/limits, HPA |
| 10 | [Namespaces, RBAC, NetworkPolicies](10-namespaces-rbac/lecon.md) | moindre privilège, base isolée |
| 11 | [StatefulSets, DaemonSets, Jobs, CronJobs](11-statefulsets-jobs/lecon.md) | sauvegarde quotidienne |
| 12 | [Helm et écosystème](12-helm-ecosysteme/lecon.md) · [mini-leçon Helm](12-helm-ecosysteme/mini-lecon-helm.md) | chart Helm complet |

### Bonus

| # | Chapitre | Contenu |
|---|---|---|
| B1 | [k9s](bonus-01-k9s/lecon.md) | piloter le cluster au clavier, diagnostiquer une panne PostgreSQL |
| B2 | [Interfaces web](bonus-02-interfaces-web/lecon.md) | Headlamp et Kubernetes Dashboard |
| B3 | [Lens et alternatives](bonus-03-lens-alternatives/lecon.md) | panorama des interfaces graphiques, Freelens, OpenLens, kubeconfig en lecture seule |

### Fil rouge

[`fil-rouge/`](fil-rouge/README.md) : l'application **task-manager** (frontend nginx + API REST PostgREST + PostgreSQL), une étape par chapitre, jusqu'au [chart Helm](fil-rouge/12-helm/task-manager/README.md).

## Prérequis machine

- Linux 64 bits (Ubuntu 22.04/24.04, Debian 12 ou équivalent), en machine physique ou virtuelle ;
- **2 CPU et 4 Go de RAM** recommandés (2 Go minimum pour k3s seul), **10 Go** de disque libre ;
- accès `sudo` et accès Internet (images de conteneurs, script d'installation) ;
- outils : `curl`, `git`, `python3` ; Docker est utile au chapitre 01 ; `helm` au chapitre 12 ; `k9s` au bonus 01.

## Installer k3s (résumé du chapitre 02)

```bash
curl -sfL https://get.k3s.io | sh -
sudo k3s kubectl get nodes

# kubectl sans sudo
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$USER": ~/.kube/config && chmod 600 ~/.kube/config
kubectl get nodes
```

k3s fournit d'emblée containerd, CoreDNS, Traefik (Ingress), ServiceLB, le provisionneur de volumes `local-path` et metrics-server. Détails, options et désinstallation : [chapitre 02](02-installation-k3s/lecon.md).

## Scripts de validation

```bash
git clone https://github.com/Milo-gdb/Kubernetes-formation.git
cd Kubernetes-formation

./05-services/verifier.sh       # un chapitre
./verifier-tout.sh              # tous les chapitres + récapitulatif
./verifier-tout.sh 03 04 b01    # une sélection (préfixes de dossiers, b01 = bonus-01)
./verifier-tout.sh -q           # récapitulatif seul
```

Exemple de sortie :

```text
=== TD 05 — Services ===
  ✅ Ex.1 — Deployment whoami prêt (2 réplicas)
  ❌ Ex.2 — Service whoami : ClusterIP avec endpoints
     ↳ Indice : Le sélecteur du Service doit correspondre aux labels des Pods.
Bilan : 1/2 vérifications réussies. Relis les indices puis relance le script.
```

Les scripts ne modifient pas le cluster (lecture via `kubectl`, requêtes `curl`, port-forwards temporaires). Codes de retour : `0` tout est bon, `1` au moins un exercice à reprendre, `2` cluster injoignable. Variables utiles : `KUBECTL` (ex. `KUBECTL="k3s kubectl"`), `RESEAU_TIMEOUT` (secondes, défaut 5). Les fonctions communes sont dans [`scripts/lib.sh`](https://github.com/Milo-gdb/Kubernetes-formation/blob/main/scripts/lib.sh).

## Consulter la formation en site web (MkDocs)

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-docs.txt
mkdocs serve                    # http://127.0.0.1:8000, rechargé à chaque modification
mkdocs build --strict           # génère le site statique dans site/
```

La configuration est dans [`mkdocs.yml`](https://github.com/Milo-gdb/Kubernetes-formation/blob/main/mkdocs.yml) : thème Material, navigation par chapitres et section **Bonus**, recherche en français, mode sombre. Le plugin `mkdocs-same-dir` permet de publier les Markdown directement depuis la racine du dépôt.

### Déploiement sur GitHub Pages

Le workflow [`.github/workflows/docs.yml`](https://github.com/Milo-gdb/Kubernetes-formation/blob/main/.github/workflows/docs.yml) construit le site (`mkdocs build --strict`) à chaque pull request, et le publie à chaque push sur `main`.

1. Sur GitHub : **Settings → Pages → Build and deployment → Source : GitHub Actions** (une seule fois).
2. Pousse sur `main` (ou lance le workflow à la main : **Actions → Site MkDocs → Run workflow**).
3. Le site est disponible sur `https://<utilisateur>.github.io/<dépôt>/`, ici <https://milo-gdb.github.io/Kubernetes-formation/>.

Alternative sans workflow : `mkdocs gh-deploy` construit le site et le pousse sur la branche `gh-pages` (choisir alors **Source : Deploy from a branch → gh-pages**).

## Licence et contributions

Les corrections et suggestions sont les bienvenues via issues et pull requests.
