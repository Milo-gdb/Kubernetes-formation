# TD 11 — StatefulSets, DaemonSets, Jobs et CronJobs

> Namespace de travail : **`td-11`**. Manifestes dans `~/formation-k8s/ch11/`.
> Vérification : `./11-statefulsets-jobs/verifier.sh`

## Exercice 1 — Un StatefulSet

1. Crée un Service headless **`web`** (port 80, sélecteur `app=web`).
2. Crée un StatefulSet **`web`** à **3 réplicas** (`nginx:1.30-alpine`) avec un `volumeClaimTemplates` nommé **`www`** (50Mi, RWO) monté sur `/usr/share/nginx/html`. Un **initContainer** `busybox:1.37` écrit le nom d'hôte du Pod dans `index.html` sur ce volume.
3. Observe l'ordre de création des Pods (`kubectl get pods -w`) et les PVC créées.
4. Depuis un Pod **`client`** (`busybox:1.37`, `sleep 3600`), appelle `http://web-1.web` : que renvoie-t-il ?

## Exercice 2 — Identité stable

1. Supprime le Pod `web-1`. Quel nom porte le Pod recréé ? Quelle PVC utilise-t-il ?
2. Passe le StatefulSet à 2 réplicas : quel Pod disparaît ? Que devient sa PVC ? Repasse à 3.

## Exercice 3 — DaemonSet

Crée un DaemonSet **`agent`** (`busybox:1.37`) qui affiche toutes les 30 secondes le nom du nœud sur lequel il tourne (indice : la *Downward API* expose `spec.nodeName` en variable d'environnement). Combien de Pods ? Pourquoi ?

## Exercice 4 — Jobs

1. Crée un Job **`lot`** qui doit réussir **4 fois**, **2 Pods à la fois** ; chaque Pod affiche `Traitement terminé` après 5 secondes.
2. Crée un Job **`echec`** dont le conteneur sort toujours en erreur (`exit 1`), avec **`backoffLimit: 2`** et `restartPolicy: Never`. Combien de Pods sont créés ? Quel est l'état final du Job ?

## Exercice 5 — CronJob

Crée un CronJob **`horloge`** qui s'exécute **toutes les minutes** et affiche la date, en ne conservant que **2** Jobs réussis dans l'historique. Attends 2 minutes et consulte les journaux du dernier Job.

## Exercice 6 — Fil rouge : sauvegarde

1. Applique `fil-rouge/11-sauvegarde/` (PVC `sauvegardes` et CronJob `sauvegarde`).
2. Déclenche immédiatement une exécution sous le nom **`sauvegarde-manuelle`**.
3. Lis ses journaux : quelle taille fait la sauvegarde ?
4. Question : pourquoi les Pods de sauvegarde portent-ils le label `postgres-client: "true"` ? Que se passerait-il sans lui ?
