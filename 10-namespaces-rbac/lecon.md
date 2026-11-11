# Chapitre 10 — Namespaces, quotas, RBAC et NetworkPolicies

> **Objectifs** : découper un cluster entre équipes ou environnements, limiter les ressources de chacun, contrôler **qui** peut faire **quoi** sur l'API, et **qui** peut parler à **qui** sur le réseau.
>
> **Durée estimée** : 3 h — **Fil rouge** : un compte en lecture seule et une base inaccessible hors de l'API.

---

## 1. Les namespaces

Un **namespace** est une partition logique du cluster : un espace de noms dans lequel deux objets ne peuvent pas porter le même nom, mais où `api` peut exister à la fois dans `dev` et dans `prod`.

```bash
kubectl get namespaces
kubectl create namespace dev
kubectl config set-context --current --namespace=dev   # namespace par défaut du contexte
kubectl get pods -A                                     # tous les namespaces
```

| Namespace | Contenu |
|---|---|
| `default` | objets créés sans préciser de namespace (à éviter pour de vrais projets) |
| `kube-system` | composants du cluster (CoreDNS, Traefik, metrics-server…) |
| `kube-public` | données lisibles par tous, même anonymes |
| `kube-node-lease` | battements de cœur (*leases*) des nœuds |

### Objets « namespacés » ou non

```bash
kubectl api-resources --namespaced=true    # Pods, Services, Deployments, Secrets, PVC, Roles...
kubectl api-resources --namespaced=false   # Nodes, PV, StorageClass, Namespaces, ClusterRoles...
```

!!! warning "Un namespace n'est pas une frontière de sécurité à lui seul"
    Par défaut, un Pod de `dev` peut joindre un Pod de `prod` sur le réseau (`api.prod.svc.cluster.local`), et un utilisateur ayant des droits sur tout le cluster voit tous les namespaces. L'isolation réelle vient de la combinaison **namespace + RBAC + quotas + NetworkPolicies** (+ Pod Security).

Supprimer un namespace supprime **tout** ce qu'il contient, PVC et données comprises.

## 2. Quotas et limites par namespace

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: quota
  namespace: dev
spec:
  hard:
    pods: "10"
    requests.cpu: "2"
    requests.memory: 2Gi
    limits.memory: 4Gi
    persistentvolumeclaims: "5"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: limites
  namespace: dev
spec:
  limits:
    - type: Container
      defaultRequest: { cpu: 100m, memory: 64Mi }   # appliqué si le conteneur ne déclare rien
      default:        { memory: 128Mi }             # limite par défaut
      max:            { memory: 1Gi }
```

Dès qu'un quota porte sur `requests.cpu`, **tout** Pod du namespace doit déclarer une request CPU (sinon il est refusé) : d'où l'intérêt d'un LimitRange qui fournit des valeurs par défaut. `kubectl describe resourcequota -n dev` montre la consommation.

## 3. Authentification : qui es-tu ?

Toute requête à l'API server est d'abord **authentifiée**. Kubernetes connaît deux sortes d'identités :

| Identité | Gérée par | Exemple |
|---|---|---|
| **Utilisateur humain** | **hors** de Kubernetes : certificat client signé par la CA du cluster, fournisseur OIDC (Keycloak, Google…) | `alice`, groupe `devs` |
| **ServiceAccount** | Kubernetes (objet namespacé) | `system:serviceaccount:task-manager:default` |

Il n'existe **pas d'objet « User »** : un utilisateur est simplement un nom (et des groupes) contenu dans un certificat ou un jeton. Ton kubeconfig k3s contient un certificat du groupe `system:masters`, qui a **tous** les droits.

Chaque Pod s'exécute sous un **ServiceAccount** (par défaut, `default` de son namespace) dont un jeton à durée limitée est monté dans `/var/run/secrets/kubernetes.io/serviceaccount/`. C'est l'identité qu'utilise une application qui appelle l'API (un opérateur, un outil de CI…).

```bash
kubectl create serviceaccount lecteur -n dev
kubectl create token lecteur -n dev --duration=1h     # jeton à durée limitée
```

## 4. Autorisation : RBAC

Une fois authentifiée, la requête est **autorisée** ou non. Le mode standard est **RBAC** (*Role-Based Access Control*), qui repose sur quatre objets :

| Objet | Portée | Rôle |
|---|---|---|
| **Role** | un namespace | liste de permissions dans ce namespace |
| **ClusterRole** | cluster | permissions sur tout le cluster ou sur des objets non namespacés ; réutilisable comme modèle |
| **RoleBinding** | un namespace | accorde un Role (ou un ClusterRole) à des sujets, **dans ce namespace** |
| **ClusterRoleBinding** | cluster | accorde un ClusterRole à des sujets, **partout** |

```text
  Sujet (User / Group / ServiceAccount) ──RoleBinding──► Role ──► règles (verbes × ressources)
```

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: lecture-pods
  namespace: dev
rules:
  - apiGroups: [""]                 # "" = groupe principal (pods, services, secrets...)
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: lecteur-lecture-pods
  namespace: dev
subjects:
  - kind: ServiceAccount
    name: lecteur
    namespace: dev
  # - kind: User
  #   name: alice
  #   apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: lecture-pods
  apiGroup: rbac.authorization.k8s.io
```

Points essentiels :

- RBAC est **additif** : aucune règle d'interdiction ; tout ce qui n'est pas explicitement permis est refusé.
- Verbes : `get`, `list`, `watch`, `create`, `update`, `patch`, `delete`, `deletecollection`, plus quelques spéciaux (`impersonate`, `bind`, `escalate`).
- Sous-ressources : `pods/log`, `pods/exec`, `pods/portforward`, `deployments/scale`…
- `list` sur les Secrets permet d'en **lire le contenu** : attention aux droits trop larges.
- Le `roleRef` d'un binding est immuable : pour changer de rôle, on supprime et recrée le binding.

### Les ClusterRoles prêts à l'emploi

| ClusterRole | Droits |
|---|---|
| `view` | lecture de la plupart des objets d'un namespace, **sauf** les Secrets |
| `edit` | lecture/écriture des objets applicatifs, sans gérer les rôles |
| `admin` | tout dans un namespace, y compris Roles et RoleBindings |
| `cluster-admin` | tout, partout |

Un **RoleBinding vers un ClusterRole** est très courant : « donner `edit` à l'équipe A, mais seulement dans le namespace `equipe-a` ».

### Tester les droits

```bash
kubectl auth can-i create deployments -n dev                       # moi
kubectl auth can-i list pods -n dev --as=system:serviceaccount:dev:lecteur
kubectl auth can-i --list -n dev --as=system:serviceaccount:dev:lecteur
```

`--as` utilise l'**usurpation d'identité** (*impersonation*), réservée aux administrateurs.

## 5. NetworkPolicies : le pare-feu entre Pods

Par défaut, **tous les Pods peuvent se parler**. Une **NetworkPolicy** sélectionne des Pods et restreint leur trafic entrant (`Ingress`) et/ou sortant (`Egress`). Dès qu'un Pod est sélectionné par une politique pour une direction, tout ce qui n'est pas autorisé dans cette direction est **refusé**.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgres-depuis-api
  namespace: task-manager
spec:
  podSelector:
    matchLabels: { app: postgres }     # les Pods protégés
  policyTypes: [Ingress]
  ingress:
    - from:
        - podSelector:
            matchLabels: { app: api }  # seules sources autorisées
      ports:
        - port: 5432
```

Les sélecteurs `from`/`to` combinent `podSelector`, `namespaceSelector` et `ipBlock`. Un modèle très répandu : une politique « tout refuser » par namespace, puis des autorisations explicites.

!!! info "Il faut un CNI qui les applique"
    Les NetworkPolicies sont appliquées par le plugin réseau. k3s embarque un contrôleur de politiques (basé sur kube-router) qui les applique avec Flannel ; Calico ou Cilium le font aussi. Avec un CNI qui ne les supporte pas, elles sont acceptées par l'API… et **ignorées**.

## 6. Fil rouge

[`10-namespaces-rbac/corrige/fil-rouge-rbac.yaml`](corrige/fil-rouge-rbac.yaml) ajoute au namespace `task-manager` :

- un ServiceAccount **`observateur`** lié au ClusterRole `view` par un RoleBinding : il peut tout consulter dans `task-manager`, sauf les Secrets, et rien ailleurs ;
- une NetworkPolicy **`postgres-depuis-api`** : seuls les Pods de l'API (et les Pods explicitement étiquetés `postgres-client: "true"`, comme la sauvegarde du chapitre 11) peuvent joindre PostgreSQL.

---

## Vocabulaire

| Terme | Définition |
|---|---|
| **Namespace** | Partition logique du cluster regroupant des objets. |
| **ResourceQuota** | Plafond de consommation de ressources d'un namespace. |
| **LimitRange** | Valeurs par défaut et bornes des ressources des conteneurs d'un namespace. |
| **Authentification** | Établir l'identité de l'auteur d'une requête. |
| **Autorisation** | Décider si cette identité a le droit d'effectuer l'action. |
| **ServiceAccount** | Identité gérée par Kubernetes, utilisée par les Pods et les automates. |
| **RBAC** | Contrôle d'accès basé sur des rôles. |
| **Role / ClusterRole** | Ensemble de permissions dans un namespace / à l'échelle du cluster. |
| **RoleBinding / ClusterRoleBinding** | Attribution d'un rôle à des sujets dans un namespace / partout. |
| **Verbe** | Action sur une ressource : get, list, watch, create, update, patch, delete. |
| **Impersonation** | Exécution d'une requête au nom d'une autre identité (`--as`). |
| **NetworkPolicy** | Règles filtrant le trafic réseau entrant/sortant de Pods sélectionnés. |
| **Moindre privilège** | Principe consistant à n'accorder que les droits strictement nécessaires. |
