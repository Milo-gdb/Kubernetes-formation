# Chapitre 04 — Deployments et ReplicaSets

> **Objectifs** : confier ses Pods à un contrôleur, passer à l'échelle, faire des mises à jour progressives sans coupure et revenir en arrière en cas de problème.
>
> **Durée estimée** : 2 h 30 — **Fil rouge** : frontend, API et PostgreSQL deviennent des Deployments.

---

## 1. Pourquoi un contrôleur ?

Au chapitre précédent, on a vu qu'un Pod supprimé ou dont le nœud tombe **n'est pas recréé**. En production, on ne crée donc presque jamais de Pod directement : on décrit à un **contrôleur** le *modèle* de Pod voulu et le *nombre* de copies, et il s'occupe du reste.

Pour les applications **sans état** (serveurs web, API), ce contrôleur est le **Deployment**.

```text
Deployment "frontend"  (stratégie de mise à jour, historique)
   └── ReplicaSet "frontend-7d9f8c"   (garantit N copies d'UN modèle de Pod)
         ├── Pod frontend-7d9f8c-abcde
         ├── Pod frontend-7d9f8c-fghij
         └── Pod frontend-7d9f8c-klmno
```

- Le **ReplicaSet** a un seul travail : maintenir **exactement N Pods** correspondant à son sélecteur. Un Pod en trop ? Il en supprime. Un Pod en moins ? Il en crée.
- Le **Deployment** pilote un ou plusieurs ReplicaSets pour gérer les **versions** : chaque modification du modèle de Pod crée un nouveau ReplicaSet, et le Deployment fait basculer progressivement les Pods de l'ancien vers le nouveau.

On ne manipule quasiment jamais les ReplicaSets à la main : on parle au Deployment.

## 2. Anatomie d'un Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  labels:
    app: web
spec:
  replicas: 3                     # nombre de Pods désiré
  selector:                       # QUELS Pods appartiennent à ce Deployment
    matchLabels:
      app: web
  template:                       # LE MODÈLE des Pods à créer
    metadata:
      labels:
        app: web                  # doit correspondre au selector !
    spec:
      containers:
        - name: nginx
          image: nginx:1.29-alpine
          ports:
            - containerPort: 80
```

La partie `template` est exactement un Pod, sans `apiVersion`/`kind`. Le point crucial est la cohérence entre `selector.matchLabels` et `template.metadata.labels` : sans elle, l'API refuse le Deployment. Le sélecteur est par ailleurs **immuable** après création.

!!! tip "Générer un squelette"
    ```bash
    kubectl create deployment web --image=nginx:1.29-alpine --replicas=3 --dry-run=client -o yaml
    ```

```bash
kubectl apply -f web.yaml
kubectl get deploy,rs,pods -l app=web
kubectl describe deployment web
```

## 3. Passer à l'échelle

```bash
kubectl scale deployment web --replicas=5     # impératif, rapide
```

ou, mieux, modifier `replicas:` dans le fichier et refaire `kubectl apply` : le fichier reste la **source de vérité**. Au chapitre 09, on verra le **HorizontalPodAutoscaler**, qui ajuste `replicas` automatiquement selon la charge.

## 4. Mises à jour progressives (rolling update)

Toute modification du `template` (image, variable, ressource…) déclenche un **déploiement** (*rollout*). Avec la stratégie par défaut `RollingUpdate`, le Deployment crée un nouveau ReplicaSet et remplace les Pods **par vagues** :

```text
temps ─────────────────────────────────────────────►
ancien RS (1.29) :  3  3  2  2  1  1  0
nouveau RS (1.30):  0  1  1  2  2  3  3
                    toujours au moins 2 Pods prêts → aucune coupure
```

Deux paramètres règlent le rythme :

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%        # combien de Pods EN PLUS du nombre voulu pendant la mise à jour
      maxUnavailable: 25%  # combien de Pods peuvent MANQUER pendant la mise à jour
```

L'autre stratégie, `Recreate`, supprime tous les anciens Pods avant de créer les nouveaux : il y a une coupure, mais jamais deux versions en même temps. Utile pour une base de données qui ne supporte pas deux instances sur le même volume (chapitre 08).

```bash
kubectl set image deployment/web nginx=nginx:1.30-alpine   # ou modifier le YAML + apply
kubectl rollout status deployment/web                       # suivre la progression
kubectl get rs -l app=web                                   # l'ancien RS est conservé, à 0
```

!!! info "Pourquoi garder les anciens ReplicaSets ?"
    Ils constituent l'**historique** et permettent un retour arrière instantané. Leur nombre est limité par `spec.revisionHistoryLimit` (10 par défaut).

## 5. Historique et retour arrière

```bash
kubectl rollout history deployment/web
kubectl rollout history deployment/web --revision=2
kubectl rollout undo deployment/web                  # revenir à la révision précédente
kubectl rollout undo deployment/web --to-revision=1  # revenir à une révision précise
```

Pour que l'historique soit lisible, on peut renseigner l'annotation `kubernetes.io/change-cause` :

```bash
kubectl annotate deployment/web kubernetes.io/change-cause="passage à nginx 1.30"
```

Un rollout raté (image inexistante, application qui plante) **ne casse pas le service** : le Deployment ne supprime les anciens Pods qu'au fur et à mesure que les nouveaux sont prêts. Il reste bloqué, et `kubectl rollout status` finit par signaler l'échec (`progressDeadlineSeconds`, 600 s par défaut).

Autres commandes utiles : `kubectl rollout pause|resume` (grouper plusieurs changements) et `kubectl rollout restart` (redémarrer tous les Pods proprement, par exemple après la modification d'une ConfigMap).

## 6. Fil rouge : trois Deployments

On remplace le Pod `frontend` par un Deployment, et on ajoute les deux autres briques :

| Deployment | Image | Réplicas | Rôle |
|---|---|---|---|
| `frontend` | `nginx:1.30-alpine` | 3 | Servir l'interface web |
| `api` | `postgrest/postgrest:v16.5` | 2 | API REST générée automatiquement depuis le schéma PostgreSQL |
| `postgres` | `postgres:17-alpine` | 1 | Base de données |

Manifestes : [`fil-rouge/04-deployment/`](../fil-rouge/04-deployment/10-frontend-deployment.yaml).

!!! warning "Choses volontairement imparfaites à ce stade"
    - Les mots de passe sont **en clair** dans les manifestes → corrigé au chapitre 07 (Secrets).
    - L'API essaie de joindre `postgres:5432`, un nom qui **n'existe pas encore** : elle répond par des erreurs tant que le Service n'est pas créé → chapitre 05.
    - Les données de PostgreSQL disparaissent si son Pod est recréé → chapitre 08.
    - On ne met **qu'une** réplique PostgreSQL : une base de données n'est pas une application sans état, et la répliquer demande bien plus qu'augmenter `replicas` (voir StatefulSet, chapitre 11).

---

## Vocabulaire

| Terme | Définition |
|---|---|
| **Deployment** | Contrôleur qui gère des Pods sans état, leur nombre et leurs mises à jour. |
| **ReplicaSet** | Contrôleur qui maintient un nombre fixe de Pods identiques. |
| **Réplique (replica)** | Une copie d'un Pod géré par un contrôleur. |
| **Sélecteur (selector)** | Critère sur les labels qui définit les objets gérés ou ciblés. |
| **Template** | Modèle de Pod à partir duquel un contrôleur crée ses Pods. |
| **Rollout** | Déploiement d'une nouvelle version du template. |
| **RollingUpdate** | Remplacement progressif des Pods, sans interruption de service. |
| **Recreate** | Suppression de tous les Pods avant création des nouveaux. |
| **maxSurge / maxUnavailable** | Pods en plus / en moins tolérés pendant une mise à jour. |
| **Révision** | Version numérotée du template dans l'historique d'un Deployment. |
| **Rollback** | Retour à une révision précédente (`kubectl rollout undo`). |
| **Sans état (stateless)** | Application qui ne stocke rien localement : chaque copie est interchangeable. |
