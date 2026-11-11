# Chapitre 03 — Les Pods

> **Objectifs** : comprendre ce qu'est un Pod et pourquoi il existe, écrire des manifestes de Pods (mono et multi-conteneurs), suivre leur cycle de vie et diagnostiquer un Pod qui ne démarre pas.
>
> **Durée estimée** : 2 h 30 — **Fil rouge** : le frontend du task-manager devient un Pod.

---

## 1. Le Pod, plus petite unité de Kubernetes

Kubernetes ne manipule jamais un conteneur seul : il manipule des **Pods**. Un Pod est une **enveloppe** autour d'un ou plusieurs conteneurs qui :

- sont **toujours placés ensemble** sur le même nœud ;
- **partagent la même adresse IP** et le même espace de ports (ils se joignent via `localhost`) ;
- peuvent **partager des volumes** ;
- naissent et meurent **ensemble**.

```text
┌────────────────── Pod "web" — IP 10.42.0.17 ──────────────────┐
│   ┌───────────────┐         ┌────────────────────┐            │
│   │ conteneur     │ ◄─────► │ conteneur          │            │
│   │ nginx :80     │localhost│ collecteur de logs │            │
│   └──────┬────────┘         └─────────┬──────────┘            │
│          └──────── volume partagé ────┘                       │
└────────────────────────────────────────────────────────────────┘
```

Une bonne image mentale : le Pod est un **« hôte logique »**, et ses conteneurs sont les processus de cet hôte.

!!! note "Un conteneur par Pod, la plupart du temps"
    Le cas le plus courant est **un seul conteneur par Pod**. On n'en met plusieurs que lorsqu'ils sont **intimement couplés** : un assistant (*sidecar*) qui complète l'application principale. On ne met **pas** l'API et la base de données dans le même Pod : elles doivent pouvoir être mises à l'échelle et redémarrées indépendamment.

## 2. Anatomie d'un manifeste de Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web                    # unique dans le namespace
  namespace: demo              # facultatif : "default" sinon
  labels:                      # étiquettes libres, servent à sélectionner
    app: web
spec:
  containers:
    - name: nginx              # nom du conteneur dans le Pod
      image: nginx:1.30-alpine # image, avec un tag précis
      ports:
        - containerPort: 80    # documentation (n'ouvre rien à lui seul)
          name: http
      env:                     # variables d'environnement
        - name: MODE
          value: demo
      command: ["nginx"]       # remplace l'ENTRYPOINT de l'image
      args: ["-g", "daemon off;"]   # remplace le CMD de l'image
```

Commandes de base :

```bash
kubectl apply -f pod.yaml            # créer ou mettre à jour (déclaratif)
kubectl get pods -o wide             # état, IP, nœud
kubectl describe pod web             # détails + événements : LE réflexe de diagnostic
kubectl logs web [-c conteneur] [-f] [--previous]
kubectl exec -it web -- sh           # shell dans le conteneur
kubectl port-forward pod/web 8080:80 # accès local temporaire
kubectl delete -f pod.yaml
```

!!! tip "Générer un squelette plutôt que l'écrire de mémoire"
    ```bash
    kubectl run web --image=nginx:1.30-alpine --dry-run=client -o yaml > pod.yaml
    ```

### Les namespaces, en bref

Un **namespace** est un espace de noms qui cloisonne les objets : deux Pods `web` peuvent coexister dans deux namespaces différents. On approfondira au chapitre 10. Pour l'instant :

```bash
kubectl create namespace td-03
kubectl get pods -n td-03
```

## 3. Cycle de vie d'un Pod

### 3.1 Les phases

| Phase | Signification |
|---|---|
| `Pending` | Accepté par le cluster mais pas encore démarré : en attente de placement, ou image en cours de téléchargement. |
| `Running` | Placé sur un nœud, au moins un conteneur tourne. |
| `Succeeded` | Tous les conteneurs se sont terminés avec succès (code 0) et ne redémarreront pas. |
| `Failed` | Tous les conteneurs sont terminés et au moins un a échoué. |
| `Unknown` | L'état ne peut pas être obtenu (nœud injoignable). |

### 3.2 Les états des conteneurs et les erreurs fréquentes

La colonne `STATUS` de `kubectl get pods` affiche souvent une **raison** plus précise que la phase :

| STATUS affiché | Cause typique | Où regarder |
|---|---|---|
| `ContainerCreating` | Téléchargement d'image, montage de volume | `describe` → Events |
| `ErrImagePull` / `ImagePullBackOff` | Nom ou tag d'image erroné, registre privé sans identifiants | `describe` → Events |
| `CrashLoopBackOff` | Le conteneur démarre puis s'arrête en boucle | `logs --previous` |
| `CreateContainerConfigError` | ConfigMap/Secret référencé introuvable | `describe` → Events |
| `OOMKilled` | Dépassement de la limite mémoire | `describe` → Last State |
| `Pending` prolongé | Pas de nœud avec assez de ressources | `describe` → Events (FailedScheduling) |

Le suffixe **BackOff** signifie que Kubernetes réessaie avec un délai croissant (10 s, 20 s, 40 s… jusqu'à 5 min).

### 3.3 La politique de redémarrage

`spec.restartPolicy` décide de ce que fait le kubelet quand un conteneur s'arrête : `Always` (défaut, pour les services), `OnFailure` (pour les traitements par lots) ou `Never`.

!!! warning "Un Pod n'est pas immortel"
    Le kubelet redémarre les **conteneurs** d'un Pod, mais si le **nœud** disparaît ou si le Pod est supprimé, personne ne le recrée. Un Pod nu est donc fragile : en pratique, on confie toujours ses Pods à un **contrôleur** (Deployment, StatefulSet, Job…). C'est l'objet du chapitre 04.

## 4. Pods multi-conteneurs

### 4.1 Le motif sidecar

Exemple : un conteneur produit du contenu, un autre le sert. Ils partagent un volume `emptyDir` (un dossier vide créé avec le Pod et détruit avec lui) :

```yaml
spec:
  volumes:
    - name: partage
      emptyDir: {}
  containers:
    - name: serveur
      image: nginx:1.30-alpine
      volumeMounts:
        - name: partage
          mountPath: /usr/share/nginx/html
    - name: generateur
      image: busybox:1.37
      command: ["sh", "-c", "while true; do date > /data/index.html; sleep 5; done"]
      volumeMounts:
        - name: partage
          mountPath: /data
```

### 4.2 Les conteneurs d'initialisation

Les **initContainers** s'exécutent **avant** les conteneurs principaux, l'un après l'autre, et doivent tous réussir. Usages : attendre qu'une dépendance soit prête, préparer des fichiers, appliquer une migration.

```yaml
spec:
  initContainers:
    - name: attendre-db
      image: busybox:1.37
      command: ["sh", "-c", "until nc -z postgres 5432; do echo attente; sleep 2; done"]
  containers:
    - name: app
      image: mon-app:1.0
```

Depuis Kubernetes 1.29, un initContainer avec `restartPolicy: Always` devient un **sidecar natif** : il démarre avant l'application et reste actif pendant toute sa vie.

## 5. Fil rouge : le frontend devient un Pod

Notre application **task-manager** se compose de trois briques :

```text
navigateur ──► frontend (nginx) ──► api (PostgREST, REST/JSON) ──► postgres
```

Première étape : faire tourner le frontend, pour l'instant une page nginx par défaut, dans un Pod du namespace `task-manager`. Le manifeste se trouve dans [`fil-rouge/03-pod/`](../fil-rouge/03-pod/10-frontend-pod.yaml). Le label `app: frontend` est important : il nous permettra plus tard de retrouver ce Pod depuis un Service.

---

## Vocabulaire

| Terme | Définition |
|---|---|
| **Pod** | Plus petite unité déployable : un ou plusieurs conteneurs partageant réseau et volumes. |
| **Namespace** | Espace de noms qui cloisonne les objets d'un cluster. |
| **Phase** | Résumé de l'état d'un Pod : Pending, Running, Succeeded, Failed, Unknown. |
| **restartPolicy** | Règle de redémarrage des conteneurs d'un Pod (Always, OnFailure, Never). |
| **CrashLoopBackOff** | Le conteneur plante à répétition ; Kubernetes espace les redémarrages. |
| **ImagePullBackOff** | L'image ne peut pas être téléchargée ; Kubernetes espace les tentatives. |
| **Sidecar** | Conteneur auxiliaire qui accompagne le conteneur principal dans le même Pod. |
| **initContainer** | Conteneur exécuté jusqu'à son terme avant le démarrage des conteneurs principaux. |
| **emptyDir** | Volume vide créé avec le Pod et supprimé avec lui. |
| **Événement (Event)** | Message horodaté émis par un composant au sujet d'un objet (visible dans `describe`). |
| **port-forward** | Tunnel temporaire entre un port local et un port d'un Pod ou Service. |
