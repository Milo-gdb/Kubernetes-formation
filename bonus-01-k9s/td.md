# TD Bonus 01 — Diagnostiquer avec k9s

> Règle du jeu : **à partir de l'exercice 3, interdiction d'utiliser `kubectl`** (sauf pour lancer le scénario). Tout se fait dans k9s.
> Fichiers dans `~/formation-k8s/bonus01/`. Vérification : `./bonus-01-k9s/verifier.sh`

## Exercice 1 — Installation et kubeconfig

1. Installe k9s et affiche sa version.
2. Vérifie que ton kubeconfig est valide : contexte courant défini, cluster joignable, fichier lisible **uniquement par toi**.
3. Lance `k9s info` : où sont ses fichiers de configuration ?

## Exercice 2 — Prise en main

Dans k9s, sur le fil rouge (namespace `task-manager`) :

1. Affiche les Pods, puis les Deployments, les Services et les events, uniquement avec le mode commande `:`.
2. Passe en vue « tous les namespaces », puis trie les Pods par mémoire consommée. Quel est le plus gourmand ?
3. Filtre pour n'afficher que les Pods portant le label `app=api`.
4. Ouvre les logs d'un Pod de l'API, puis un shell dans le Pod PostgreSQL et lance `psql -U taskmanager -c 'select count(*) from tasks'`.
5. Crée un port-forward vers le Service `frontend` sur le port local **8080** et ouvre `http://localhost:8080` (ou `curl localhost:8080`). Laisse-le actif pour la vérification.

## Exercice 3 — La base ne démarre plus

Lance le scénario de panne (copie autonome du task-manager dans le namespace `k9s-lab`) :

```bash
kubectl apply -f bonus-01-k9s/scenario/panne-postgres.yaml
```

Au bout de quelques instants, l'application est en panne. **Uniquement avec k9s** :

1. Trouve le Pod en erreur et son statut. Combien de redémarrages ?
2. Explique pourquoi l'API n'est pas prête non plus.
3. Trouve **le message d'erreur exact** du conteneur PostgreSQL et la cause de la panne. Note dans `~/formation-k8s/bonus01/diagnostic.txt` : le statut observé, le message d'erreur, la cause, et les touches k9s utilisées.
4. Les ressources du namespace contiennent tout ce qu'il faut pour réparer. Corrige le Deployment depuis k9s (`e`) et observe le retour à la normale de PostgreSQL **et** de l'API.

## Exercice 4 — Mode lecture seule

Lance `k9s --readonly -n k9s-lab` et essaie de supprimer un Pod. Que se passe-t-il ? Dans quel contexte ce mode est-il utile ?
