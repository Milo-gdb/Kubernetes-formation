# TD 12 — Helm

> Namespace de travail : **`td-12`** (et `tm-helm` pour le fil rouge). Fichiers dans `~/formation-k8s/ch12/`.
> Vérification : `./12-helm-ecosysteme/verifier.sh`

## Exercice 1 — Installer un chart public

1. Ajoute le dépôt `podinfo` (`https://stefanprodan.github.io/podinfo`) et cherche le chart `podinfo`.
2. Lis ses valeurs disponibles. Quelle valeur règle le nombre de réplicas ? Laquelle le message affiché par l'interface ?
3. Installe-le dans `td-12` sous le nom de release **`demo`** avec **2 réplicas**.

## Exercice 2 — Mettre à jour avec un fichier de valeurs

1. Écris `~/formation-k8s/ch12/demo-valeurs.yaml` qui conserve 2 réplicas et règle le message de l'interface à **`Bonjour Helm`**.
2. Mets à jour la release avec ce fichier. Vérifie avec `helm get values` et un `port-forward` sur le Service (port 9898).
3. Affiche l'historique. Fais un `helm rollback` vers la révision 1, observe l'historique, puis réapplique ton fichier de valeurs : la release doit finir avec le message `Bonjour Helm`.

## Exercice 3 — Ton propre chart

1. Génère un squelette **`~/formation-k8s/ch12/mon-site`** avec `helm create`.
2. Modifie `values.yaml` pour utiliser l'image `nginx` en tag `1.30-alpine` et ajoute une valeur **`message`** (défaut : `Mon premier chart`).
3. Ajoute un ConfigMap modèle qui contient un `index.html` affichant `{{ .Values.message }}`, et monte-le dans le conteneur sur `/usr/share/nginx/html`.
4. `helm lint` doit passer sans erreur ; `helm template` doit montrer ton message. Installe le chart dans `td-12` sous le nom **`site`** avec `--set message="Déployé par Helm"`.

## Exercice 4 — Fil rouge : le task-manager en une commande

1. Lis `fil-rouge/12-helm/task-manager/values.yaml` et les modèles.
2. Installe le chart dans le namespace **`tm-helm`** (release **`task-manager`**) avec l'hôte **`helm.task-manager.local`**, sans hôte d'API séparé, et l'autoscaling activé.
3. Récupère le mot de passe PostgreSQL généré (la commande est affichée par les NOTES).
4. Fais une mise à jour (`helm upgrade --reuse-values`) qui passe le frontend en `nginx:1.29-alpine` : le mot de passe a-t-il changé ? L'application fonctionne-t-elle toujours ?
5. Bonus : active la sauvegarde (`backup.enabled=true`) et déclenche-la manuellement.
