# TD 04 — Deployments

> Namespace de travail : **`td-04`**. Manifestes dans `~/formation-k8s/ch04/`.
> Vérification : `./04-deployments/verifier.sh`

## Exercice 1 — Un Deployment

Écris un Deployment **`web`** dans `td-04` : 3 réplicas de `nginx:1.29-alpine` (conteneur nommé `nginx`), avec le label `app: web`.

Observe la hiérarchie créée : `kubectl get deploy,rs,pods -n td-04`. Comment sont construits les noms des Pods ?

## Exercice 2 — Auto-réparation et mise à l'échelle

1. Supprime un des Pods de `web`. Que se passe-t-il ?
2. Passe le Deployment à **5 réplicas** en modifiant ton fichier puis en le réappliquant.

## Exercice 3 — Mise à jour progressive

1. Dans un terminal, lance `kubectl get pods -n td-04 -w`.
2. Mets à jour l'image vers **`nginx:1.30-alpine`**.
3. Observe le remplacement des Pods, puis consulte `kubectl rollout history`.

## Exercice 4 — Mise à jour ratée et retour arrière

1. Déploie l'image `nginx:9.99-alpine` (qui n'existe pas). Que deviennent les Pods ? Le service est-il interrompu ?
2. Reviens à la version précédente **avec `kubectl rollout undo`**.
3. Vérifie que les 5 Pods sont en `nginx:1.30-alpine` et que l'historique a bien enregistré toutes ces étapes.

## Exercice 5 — Fil rouge : trois Deployments

Dans le namespace `task-manager` :

1. Supprime le Pod `frontend` du chapitre 03.
2. Crée les trois Deployments décrits dans la leçon : `frontend` (3 réplicas), `api` (2 réplicas) et `postgres` (1 réplica). Les images et variables d'environnement nécessaires sont indiquées dans la leçon ; référence : `fil-rouge/04-deployment/`.
3. Regarde les journaux de l'API : que dit-elle ? Pourquoi ?

## Pour aller plus loin

- Règle `maxSurge: 0` et `maxUnavailable: 1` puis refais une mise à jour : quelle différence ?
- Que se passe-t-il si tu modifies à la main les labels d'un Pod géré par le Deployment (`kubectl label pod <pod> app=autre --overwrite`) ?
