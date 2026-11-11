# TD 03 — Les Pods

> Namespace de travail : **`td-03`** (crée-le d'abord). Écris tes manifestes dans `~/formation-k8s/ch03/`.
> Vérification : `./03-pods/verifier.sh`

## Exercice 1 — Un premier Pod

Écris un manifeste pour un Pod **`web`** dans `td-03` :

- image `nginx:1.30-alpine`, port 80 nommé `http` ;
- label `app: web`.

Applique-le, puis : affiche son IP et son nœud, consulte ses événements, et ouvre la page d'accueil depuis ton navigateur grâce à `kubectl port-forward`.

## Exercice 2 — Un Pod bavard

Crée un Pod **`bavard`** (image `busybox:1.37`) qui :

- reçoit une variable d'environnement `PRENOM` contenant ton prénom ;
- affiche toutes les 5 secondes la phrase `Bonjour <PRENOM> depuis Kubernetes`.

Suis ses journaux en direct.

## Exercice 3 — Pod multi-conteneurs

Crée un Pod **`duo`** avec **deux conteneurs** partageant un volume `emptyDir` :

- `serveur` : `nginx:1.30-alpine`, qui sert le contenu du volume ;
- `horloge` : `busybox:1.37`, qui écrit toutes les 5 secondes un fichier `index.html` contenant `Heure : ` suivi de la date.

Vérifie avec `port-forward` que la page change toutes les 5 secondes. Depuis le conteneur `horloge`, peux-tu joindre nginx avec `wget -qO- localhost` ? Pourquoi ?

## Exercice 4 — Diagnostic

Applique le manifeste fourni [`td/pod-casse.yaml`](td/pod-casse.yaml). Le Pod **`casse`** ne démarre pas.

1. Quel STATUS affiche `kubectl get pods` ?
2. Trouve la cause **avec `kubectl describe`**.
3. Répare le Pod pour qu'il passe en `Running` (indice : certains champs d'un Pod existant ne sont pas modifiables…).

## Exercice 5 — Fil rouge : le frontend

Crée le namespace **`task-manager`** et, dedans, un Pod **`frontend`** (`nginx:1.30-alpine`, port 80 nommé `http`) portant le label **`app: frontend`**.

Tu peux t'inspirer de la leçon ; la solution de référence est dans `fil-rouge/03-pod/`.

## Pour aller plus loin

- Ajoute à `web` un **initContainer** qui écrit une page d'accueil personnalisée dans un `emptyDir` monté ensuite par nginx.
- Supprime le Pod `web`. Est-il recréé ? Compare avec l'exercice 5 du TD 02.
