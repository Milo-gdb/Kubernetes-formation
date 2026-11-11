# TD 09 — Sondes, ressources et autoscaling

> Namespace de travail : **`td-09`**. Manifestes dans `~/formation-k8s/ch09/`.
> Vérification : `./09-sondes-ressources-autoscaling/verifier.sh`

## Exercice 1 — Une liveness qui échoue

Crée un Pod **`vivant`** (`busybox:1.37`) dont le conteneur :

- crée le fichier `/tmp/sante`, attend 30 secondes, le supprime, puis dort longtemps ;
- possède une **livenessProbe** de type `exec` qui teste l'existence de `/tmp/sante` toutes les 5 secondes.

Observe le Pod pendant 2 minutes (`kubectl get pod vivant -w`) et les événements (`kubectl describe`). Que se passe-t-il, et pourquoi en boucle ?

## Exercice 2 — Readiness et Service

1. Crée un Deployment **`web`** (2 réplicas, `nginx:1.30-alpine`) avec une **readinessProbe** HTTP sur `/` port 80 et une **livenessProbe** (à toi de choisir son type : relis la question 2 avant !), plus un Service ClusterIP **`web`**. Donne au conteneur des **requests** de `50m` CPU et `32Mi` de mémoire.
2. Dans l'un des Pods, supprime la page d'accueil : `kubectl exec <pod> -- rm /usr/share/nginx/html/index.html`. Que deviennent la colonne READY et les endpoints du Service ? Le Pod est-il redémarré ?
3. Remets les choses en ordre (indice : supprimer le Pod suffit).

## Exercice 3 — OOMKilled

Crée un Pod **`gourmand`** (`busybox:1.37`) avec une **limite mémoire de 64Mi**, qui exécute :

```sh
a=$(head -c 100000000 /dev/zero | tr "\0" a); sleep 3600
```

Quel statut, quelle raison et quel code de sortie observes-tu ?

## Exercice 4 — Classes QoS

Crée un Pod **`garanti`** (`busybox:1.37`, `sleep 3600`) de classe **Guaranteed**. Quelle est la classe des Pods de `web` ? Du Pod `vivant` ?

## Exercice 5 — HPA

1. Crée un HPA **`web`** sur le Deployment `web` : **2 à 6** réplicas, cible **50 %** d'utilisation CPU.
2. Vérifie que la colonne TARGETS affiche une valeur (et non `<unknown>`).
3. Génère de la charge et observe la montée en charge :

```bash
kubectl run -n td-09 charge --image=busybox:1.37 --restart=Never -- \
  sh -c 'while true; do wget -q -O- http://web >/dev/null; done'
kubectl get hpa web -n td-09 -w
```

4. Supprime le Pod `charge` et observe la redescente (patience : 5 minutes de stabilisation).

## Exercice 6 — Fil rouge

Applique `fil-rouge/09-sondes-ressources/` puis :

- vérifie les sondes et ressources de chaque composant (`kubectl describe deploy -n task-manager`) ;
- vérifie les deux HPA (`frontend` et `api`) ;
- redémarre PostgreSQL et observe la colonne READY des Pods de l'API pendant quelques secondes.
