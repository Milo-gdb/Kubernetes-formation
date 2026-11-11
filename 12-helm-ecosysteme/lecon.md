# Chapitre 12 — Helm et l'écosystème Kubernetes

> **Objectifs** : installer, configurer, mettre à jour et désinstaller des applications avec Helm, écrire son propre chart, et situer Helm dans l'écosystème (Kustomize, GitOps, opérateurs, observabilité).
>
> **Durée estimée** : 3 h 30 — **Mini-leçon associée** : [Helm en profondeur](mini-lecon-helm.md) — **Fil rouge** : tout le task-manager en une commande.

---

## 1. Le problème : des dizaines de YAML presque identiques

À la fin du chapitre 11, le task-manager compte une vingtaine d'objets répartis dans une dizaine de fichiers. Pour le déployer en recette **et** en production, il faudrait dupliquer ces fichiers en changeant le nom d'hôte, le nombre de réplicas, la taille du volume… et garder les copies synchronisées. Pour installer un logiciel tiers (une base, un outil de supervision), il faudrait écrire tous ses manifestes soi-même.

**Helm** est le **gestionnaire de paquets** de Kubernetes, projet diplômé de la CNCF. Il apporte :

- des **charts** : des paquets de manifestes **paramétrables** ;
- des **valeurs** : les paramètres d'une installation ;
- des **releases** : des installations nommées, versionnées, que l'on peut mettre à jour et **annuler**.

```text
  chart (modèles)  +  valeurs  ──helm install──►  manifestes rendus  ──►  API server
                                                       │
                                            release "task-manager", révision 1, 2, 3...
```

## 2. Vocabulaire de base

| Notion | Définition | Analogie |
|---|---|---|
| **Chart** | répertoire (ou archive `.tgz`) contenant des modèles de manifestes et des valeurs par défaut | un paquet `.deb` |
| **Values** | paramètres fournis à l'installation (`values.yaml`, `-f`, `--set`) | la configuration |
| **Release** | une instance installée d'un chart dans un namespace, avec un nom | un logiciel installé |
| **Révision** | chaque `install`/`upgrade`/`rollback` crée une nouvelle révision de la release | l'historique des versions |
| **Repository** | serveur HTTP ou registre OCI hébergeant des charts | un dépôt APT |

Helm 3 n'a **aucun composant dans le cluster** : c'est un client qui parle à l'API avec ton kubeconfig (donc avec **tes** droits RBAC). L'état des releases est stocké dans des Secrets du namespace (`sh.helm.release.v1.<nom>.v<révision>`).

## 3. Utiliser des charts existants

```bash
# Dépôts classiques (HTTP)
helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo update
helm search repo podinfo
helm show values podinfo/podinfo | less        # TOUJOURS lire les valeurs disponibles

# Installation
helm install demo podinfo/podinfo -n td-12 --create-namespace --set replicaCount=2
helm list -n td-12
helm status demo -n td-12

# Registres OCI : pas de "repo add"
helm install podinfo-oci oci://ghcr.io/stefanprodan/charts/podinfo --version 6.17.0
```

L'annuaire public **Artifact Hub** (artifacthub.io) référence des milliers de charts. Avant d'en adopter un, vérifie qui le maintient, sa fréquence de mise à jour et les images qu'il utilise.

### Fournir des valeurs

Par ordre de priorité croissante :

1. `values.yaml` du chart (défauts) ;
2. fichiers `-f mes-valeurs.yaml` (le dernier l'emporte) ;
3. `--set cle=valeur` / `--set-string` / `--set-file`.

```yaml
# mes-valeurs.yaml
replicaCount: 3
ui:
  message: "Bonjour depuis Helm"
```

```bash
helm upgrade demo podinfo/podinfo -n td-12 -f mes-valeurs.yaml
helm get values demo -n td-12          # valeurs fournies par l'utilisateur
helm get manifest demo -n td-12        # manifestes réellement appliqués
```

!!! warning "upgrade et valeurs"
    `helm upgrade` repart des valeurs par défaut du chart + celles que tu passes **dans cette commande**. Les `--set` d'une installation précédente sont **oubliés**, sauf avec `--reuse-values` (ou mieux : garde toujours tes valeurs dans un fichier versionné et repasse-le à chaque fois).

### Cycle de vie

```bash
helm upgrade --install demo podinfo/podinfo -n td-12 -f valeurs.yaml   # idempotent : idéal en CI
helm history demo -n td-12
helm rollback demo 1 -n td-12          # crée une NOUVELLE révision identique à la 1
helm uninstall demo -n td-12
```

`--wait` fait attendre Helm jusqu'à ce que les ressources soient prêtes (Deployments disponibles, PVC liées…) et `--atomic` annule automatiquement une mise à jour ratée.

## 4. Écrire un chart

```bash
helm create mon-chart        # squelette commenté
```

```text
mon-chart/
├── Chart.yaml          # nom, version du chart, appVersion, dépendances
├── values.yaml         # valeurs par défaut (documentées !)
├── charts/             # charts dépendants (sous-charts)
└── templates/
    ├── _helpers.tpl    # modèles nommés réutilisables (noms, labels)
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    └── NOTES.txt       # message affiché après l'installation
```

Les modèles utilisent le langage de templates de Go, enrichi de la bibliothèque **Sprig** :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "mon-chart.fullname" . }}
  labels:
    {{- include "mon-chart.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  template:
    spec:
      containers:
        - name: app
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
```

| Élément | Rôle |
|---|---|
| `.Values`, `.Release`, `.Chart`, `.Capabilities` | objets disponibles dans les modèles |
| `{{- ... }}` / `{{ ... -}}` | supprime les espaces/retours à la ligne à gauche / à droite |
| `if`, `range`, `with` | conditions, boucles, changement de contexte |
| `include`, `toYaml`, `nindent`, `quote`, `default` | fonctions les plus utilisées |

Outils indispensables pendant l'écriture :

```bash
helm lint mon-chart                              # erreurs de structure et de syntaxe
helm template essai mon-chart -f valeurs.yaml    # rend les manifestes sans rien installer
helm install essai mon-chart --dry-run --debug   # rendu validé par le serveur
helm package mon-chart                           # produit mon-chart-0.1.0.tgz
```

Détails dans la [mini-leçon Helm](mini-lecon-helm.md) : helpers, hooks, dépendances, `lookup`, schéma de valeurs.

## 5. Fil rouge : le chart task-manager

[`fil-rouge/12-helm/task-manager/`](../fil-rouge/12-helm/task-manager/values.yaml) réunit tout ce qui a été construit depuis le chapitre 03 :

| Fonctionnalité | Chapitre | Dans le chart |
|---|---|---|
| frontend nginx, API PostgREST | 03-04 | `templates/frontend.yaml`, `templates/api.yaml` |
| Services | 05 | dans les mêmes fichiers |
| Ingress | 06 | `templates/ingress.yaml`, valeurs `ingress.*` |
| ConfigMaps, Secrets | 07 | `templates/configmaps.yaml` (fichiers de `files/`), `templates/secrets.yaml` |
| Persistance | 08 | PostgreSQL en **StatefulSet** avec `volumeClaimTemplates` |
| Sondes, ressources, HPA | 09 | valeurs `*.resources`, `autoscaling.enabled` |
| NetworkPolicy | 10 | `networkPolicy.enabled` |
| Sauvegarde CronJob | 11 | `backup.enabled` |

Améliorations par rapport aux manifestes bruts :

- **mot de passe généré** à l'installation (`randAlphaNum`), puis **conservé** lors des mises à jour grâce à `lookup` qui relit le Secret existant : plus aucun secret dans le dépôt ;
- annotations `checksum/config` : modifier la configuration déclenche automatiquement un rolling update ;
- noms préfixés par la release : on peut installer plusieurs instances côte à côte (recette, production) ;
- labels standard `app.kubernetes.io/*`.

```bash
helm install task-manager fil-rouge/12-helm/task-manager -n tm-helm --create-namespace \
  --set ingress.host=helm.task-manager.local --set ingress.apiHost=""
```

!!! warning "`--wait` et volumes `WaitForFirstConsumer`"
    Avec `backup.enabled=true`, la PVC des sauvegardes reste `Pending` jusqu'à la première exécution du CronJob (classe `local-path` en `WaitForFirstConsumer`). Un `helm install --wait` attendrait alors indéfiniment qu'elle soit liée : n'utilise pas `--wait` dans ce cas, ou surveille plutôt `kubectl rollout status`.

## 6. Panorama de l'écosystème

Kubernetes n'est qu'un socle : un cluster de production s'accompagne de nombreux outils, la plupart hébergés par la **CNCF**.

| Besoin | Outils (exemples) |
|---|---|
| **Personnaliser des manifestes** | **Kustomize** (intégré à kubectl : `kubectl apply -k`, superposition de *patches* sans templates) — alternative ou complément de Helm |
| **GitOps** (Git comme source de vérité, synchronisation continue) | **Argo CD**, **Flux** |
| **Observabilité** | **Prometheus** + Grafana (métriques), Loki / Elasticsearch (journaux), **OpenTelemetry**, Jaeger / Tempo (traces) |
| **Exposition et trafic** | Traefik, NGINX Ingress Controller, Envoy Gateway, **Gateway API** ; service mesh **Istio**, **Linkerd** |
| **Réseau (CNI)** | Flannel (k3s), **Cilium**, Calico |
| **Stockage** | **Longhorn**, **Rook/Ceph**, pilotes CSI des clouds |
| **Sécurité** | **cert-manager**, Sealed Secrets, External Secrets, **Kyverno** / OPA Gatekeeper (politiques), **Falco** (détection), Trivy (scan d'images) |
| **Sauvegarde** | **Velero** |
| **Opérateurs** | CloudNativePG, Strimzi (Kafka), Prometheus Operator… (Operator Framework, Kubebuilder) |
| **Interfaces** | k9s, Headlamp, Freelens… → chapitres [bonus](../bonus-01-k9s/lecon.md) |
| **Distributions** | k3s, RKE2, k0s, Talos, OpenShift, services managés (EKS, GKE, AKS…) |

!!! tip "Et après ?"
    Pour aller plus loin : passe au multi-nœuds (ajoute un agent k3s : `curl -sfL https://get.k3s.io | K3S_URL=... K3S_TOKEN=... sh -`), déploie le chart task-manager via **Argo CD**, ajoute **Prometheus**, et prépare les certifications **KCNA**, **CKAD** ou **CKA** de la Linux Foundation.

---

## Vocabulaire

| Terme | Définition |
|---|---|
| **Helm** | Gestionnaire de paquets de Kubernetes. |
| **Chart** | Paquet Helm : modèles de manifestes + valeurs par défaut + métadonnées. |
| **Values** | Paramètres injectés dans les modèles d'un chart. |
| **Release** | Installation nommée d'un chart dans un namespace. |
| **Révision** | Version numérotée d'une release, créée à chaque install/upgrade/rollback. |
| **Template** | Fichier de manifeste contenant des expressions `{{ }}` évaluées par Helm. |
| **Helper (`_helpers.tpl`)** | Modèle nommé réutilisable, appelé avec `include`. |
| **Artifact Hub** | Annuaire public de charts et autres paquets cloud-native. |
| **OCI** | Format standard des registres d'images, également utilisé pour stocker des charts. |
| **Kustomize** | Outil de personnalisation de manifestes par superposition de patches. |
| **GitOps** | Pratique où l'état du cluster est décrit dans Git et synchronisé automatiquement. |
| **CNCF** | *Cloud Native Computing Foundation*, fondation qui héberge Kubernetes, Helm, Prometheus… |
