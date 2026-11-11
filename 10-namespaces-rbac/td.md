# TD 10 — Namespaces, quotas, RBAC et NetworkPolicies

> Namespace de travail : **`td-10`**. Manifestes dans `~/formation-k8s/ch10/`.
> Vérification : `./10-namespaces-rbac/verifier.sh`

## Exercice 1 — Namespace et quota

1. Crée le namespace **`td-10`** avec le label **`equipe=formation`**.
2. Ajoute un ResourceQuota **`quota`** : au plus **10 Pods**, `requests.cpu` **1**, `requests.memory` **512Mi**.
3. Ajoute un LimitRange **`limites`** qui donne par défaut aux conteneurs une request de **50m** CPU et **32Mi** de mémoire, et une limite mémoire de **64Mi**.
4. Crée un Deployment **`remplissage`** (`nginx:1.30-alpine`, **sans** section `resources`) et passe-le à 15 réplicas. Combien de Pods tournent ? Où trouver la raison (indice : les événements du **ReplicaSet**) ? Ramène-le à 3 réplicas.

## Exercice 2 — Un compte en lecture seule

1. Crée un ServiceAccount **`lecteur`** dans `td-10`.
2. Crée un Role **`lecture`** autorisant `get`, `list`, `watch` sur les Pods, leurs journaux (`pods/log`) et les Deployments.
3. Lie-le à `lecteur` par un RoleBinding **`lecteur-lecture`**.
4. Vérifie avec `kubectl auth can-i ... --as=system:serviceaccount:td-10:lecteur` qu'il peut lister les Pods de `td-10`, mais ni les supprimer, ni lire les Secrets, ni lister les Pods de `kube-system`.

## Exercice 3 — Utiliser vraiment ce compte

1. Génère un jeton pour `lecteur` (`kubectl create token`).
2. Fabrique un fichier kubeconfig **`~/formation-k8s/ch10/lecteur.kubeconfig`** qui utilise ce jeton (même serveur et même CA que ton kubeconfig).
3. Avec `KUBECONFIG=~/formation-k8s/ch10/lecteur.kubeconfig kubectl get pods -n td-10`, vérifie que ça marche, puis tente un `delete`.

## Exercice 4 — Déployeur

Crée un ServiceAccount **`deployeur`** qui peut **modifier** les objets applicatifs de `td-10` (utilise un ClusterRole existant !) mais n'a **aucun** droit ailleurs.

## Exercice 5 — NetworkPolicy

1. Crée un Pod **`serveur`** (`nginx:1.30-alpine`, label `role=serveur`) exposé par un Service **`serveur`**, et deux Pods clients `busybox:1.37` (`sleep 3600`) : **`autorise`** (label `acces=oui`) et **`intrus`** (sans ce label).
2. Crée une NetworkPolicy **`serveur-restreint`** : les Pods `role=serveur` n'acceptent en entrée que le trafic des Pods `acces=oui`, sur le port 80.
3. Teste `wget -qO- -T 3 http://serveur` depuis chaque client.

## Exercice 6 — Fil rouge

Dans `task-manager` :

1. ServiceAccount **`observateur`** lié au ClusterRole **`view`** par un RoleBinding **`observateur-view`** ;
2. NetworkPolicy **`postgres-depuis-api`** : seuls les Pods `app=api` peuvent joindre PostgreSQL sur 5432.

Vérifie que l'application fonctionne toujours, et qu'un Pod de test ne peut plus joindre `postgres:5432` (`nc -zv -w 3 postgres 5432`).
