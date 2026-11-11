# TD 05 — Services

> Namespace de travail : **`td-05`**. Manifestes dans `~/formation-k8s/ch05/`.
> Vérification : `./05-services/verifier.sh`

## Exercice 1 — Un Service ClusterIP

1. Crée un Deployment **`whoami`** : 2 réplicas de `traefik/whoami:v1.12.0` (qui écoute sur le port 80 et répond avec le nom du Pod), label `app: whoami`.
2. Expose-le avec un Service **`whoami`** de type ClusterIP sur le port 80.
3. Affiche les endpoints du Service. Combien d'adresses ? Correspondent-elles aux IP des Pods ?
4. Avec `port-forward` sur le Service, appelle-le plusieurs fois : le `Hostname` affiché change-t-il ? (Note : `port-forward` choisit un seul Pod ; refais le test depuis un Pod du cluster à l'exercice 4.)

## Exercice 2 — NodePort

Crée un second Service **`whoami-nodeport`**, de type NodePort, sur le **port de nœud 30500**, ciblant les mêmes Pods. Teste-le avec `curl http://<IP-du-nœud>:30500`.

## Exercice 3 — Service headless

Crée un Service **`whoami-headless`** sans ClusterIP, ciblant les mêmes Pods.

## Exercice 4 — DNS et répartition de charge

1. Lance un Pod **`client`** (`busybox:1.37`, commande `sleep 3600`) dans `td-05`.
2. Depuis ce Pod, avec `nslookup`, compare les réponses pour `whoami` et `whoami-headless`. Explique la différence.
3. Toujours depuis `client`, appelle `wget -qO- http://whoami` plusieurs fois. La charge est-elle répartie ?
4. Depuis `client`, résous le Service `api` du namespace `task-manager` (s'il existe déjà).

## Exercice 5 — Casser puis réparer

Modifie le sélecteur du Service `whoami` en `app: whoam` (faute de frappe). Que montrent les endpoints ? Que répond `wget` depuis `client` ? Remets le bon sélecteur.

## Exercice 6 — Fil rouge : les Services du task-manager

Crée dans `task-manager` les trois Services décrits dans la leçon (`frontend` en NodePort 30080, `api` et `postgres` en ClusterIP). Puis :

- vérifie que chaque Service a des endpoints ;
- ouvre `http://<IP-du-nœud>:30080` ;
- relis les journaux de l'API : la connexion à PostgreSQL fonctionne-t-elle maintenant ?

Référence : `fil-rouge/05-services/`.
