# TD 07 — ConfigMaps et Secrets

> Namespace de travail : **`td-07`**. Manifestes dans `~/formation-k8s/ch07/`.
> Vérification : `./07-config-secrets/verifier.sh`

## Exercice 1 — ConfigMap en variables d'environnement

1. Crée un ConfigMap **`parametres`** contenant `COULEUR=bleu` et `TAILLE=42`.
2. Crée un Pod **`lecteur-env`** (`busybox:1.37`, commande `sleep 3600`) qui reçoit **toutes** les clés de `parametres` comme variables d'environnement.
3. Vérifie avec `kubectl exec lecteur-env -- env`.

## Exercice 2 — ConfigMap en fichier

1. Écris un fichier `message.txt` contenant `Bonjour depuis un ConfigMap`.
2. Crée un ConfigMap **`fichiers`** à partir de ce fichier (la clé doit être `message.txt`).
3. Crée un Pod **`lecteur-vol`** (`busybox:1.37`) qui monte ce ConfigMap dans `/config` et exécute en boucle `cat /config/message.txt; sleep 5`.
4. Modifie le ConfigMap (`kubectl edit`) pour que le message devienne `Message mis à jour`. Suis les journaux du Pod : combien de temps faut-il pour que le changement apparaisse ? Que se passerait-il pour une variable d'environnement ?

## Exercice 3 — Un Secret

1. Crée un Secret **`identifiants`** avec `utilisateur=admin` et `motdepasse=Formation-K8s`.
2. Affiche son YAML, puis décode la valeur de `motdepasse` en une seule commande.
3. Crée un Pod **`lecteur-secret`** (`busybox:1.37`, `sleep 3600`) qui expose `motdepasse` dans la variable **`DB_PASSWORD`** et monte le Secret entier dans **`/secrets`**.
4. Que montre `kubectl describe secret identifiants` ? Et `kubectl exec lecteur-secret -- df -h /secrets` (type de système de fichiers) ?

## Exercice 4 — ConfigMap immuable

Crée un ConfigMap **`version`** immuable avec `NUMERO=1`, puis essaie de le modifier. Quel message obtiens-tu ?

## Exercice 5 — Fil rouge : sortir les identifiants des Deployments

Dans `task-manager`, applique la version `fil-rouge/07-config-secrets/` en comprenant chaque objet :

- Secrets `postgres-credentials` et `api-db`, ConfigMaps `api-config`, `postgres-init`, `frontend-nginx`, `frontend-html` ;
- aucun `value:` contenant un mot de passe ne doit subsister dans les Deployments.

!!! warning "Base de données à réinitialiser"
    Le script `init.sql` n'est exécuté par l'image PostgreSQL que si le répertoire de données est **vide**. Si PostgreSQL tourne déjà (chapitre 04-06, sans volume), supprime son Pod pour qu'il redémarre à vide : `kubectl delete pod -n task-manager -l app=postgres`.

Puis ouvre `http://task-manager.local`, crée une tâche, marque-la comme terminée.
