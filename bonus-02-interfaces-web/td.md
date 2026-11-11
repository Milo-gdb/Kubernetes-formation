# TD Bonus 02 — Headlamp et Kubernetes Dashboard

> Fichiers dans `~/formation-k8s/bonus02/`. Vérification : `./bonus-02-interfaces-web/verifier.sh`

## Exercice 1 — Installer Headlamp

Installe Headlamp avec Helm dans le namespace **`headlamp`** (release **`headlamp`**). Accède à l'interface par un port-forward et connecte-toi avec un jeton du ServiceAccount créé par le chart. Explore le fil rouge (`task-manager`) : Pods, logs de l'API, events, graphe des ressources.

## Exercice 2 — Un compte en lecture seule

1. Crée dans `headlamp` un ServiceAccount **`observateur`** qui peut **lire** tout le cluster (sauf les Secrets) mais rien modifier, en réutilisant un ClusterRole fourni par Kubernetes.
2. Génère un jeton pour ce compte, déconnecte-toi de Headlamp et reconnecte-toi avec. Essaie de supprimer un Pod du fil rouge : que se passe-t-il ?

## Exercice 3 — Exposer Headlamp

Rends Headlamp accessible sur **`http://headlamp.local`** via Traefik (pense à `/etc/hosts`).

## Exercice 4 — Le Dashboard historique

1. Installe le Kubernetes Dashboard 2.7.0 (manifeste de la leçon) et accède-y en HTTPS par port-forward. Connecte-toi avec le jeton `observateur`.
2. Rédige `~/formation-k8s/bonus02/comparaison.md` : au moins trois différences entre Headlamp et le Dashboard, et une raison de ne pas choisir le Dashboard aujourd'hui.

## Exercice 5 — Ménage

Pourquoi faut-il supprimer le ClusterRoleBinding `headlamp-admin` (ou désactiver sa création dans les valeurs du chart) sur un cluster partagé ? Comment le faire avec Helm ?
