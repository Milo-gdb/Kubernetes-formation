# Corrigé TD bonus 01 — k9s

## Exercice 1

```bash
k9s version
kubectl config current-context            # contexte défini
kubectl cluster-info                      # cluster joignable
ls -l ~/.kube/config                      # -rw------- : sinon chmod 600 ~/.kube/config
k9s info                                  # ~/.config/k9s/...
```

## Exercice 2

| Question | Touches |
|---|---|
| vues | `:pods`, `:deploy`, `:svc`, `:events` (ou `:ev`) |
| tous les namespaces, tri mémoire | `0` puis `Shift-m` (PostgreSQL ou Traefik en général) |
| filtre par label | `/-l app=api` puis `Entrée` |
| logs | sélectionner un Pod `api-...`, `l` |
| shell | sélectionner `postgres-...`, `s`, puis `psql -U taskmanager -c 'select count(*) from tasks'`, `exit` |
| port-forward | `:svc`, sélectionner `frontend`, `Shift-f`, port local `8080`, OK ; vérifier dans `:pf` |

## Exercice 3

1. `:pods` dans `k9s-lab` (`:ns` puis `Entrée` sur `k9s-lab`) : `postgres-...` est en **`CrashLoopBackOff`**, la colonne `RESTARTS` augmente.
2. `api-...` est `Running` mais `0/1` : `d` montre que la sonde de readiness `/ready` échoue, et `l` affiche des erreurs de connexion à la base. L'API dépend de PostgreSQL : panne en cascade.
3. Sur `postgres-...`, `p` (logs précédents) affiche :

   ```text
   Error: Database is uninitialized and superuser password is not specified.
          You must specify POSTGRES_PASSWORD to a non-empty value for the
          superuser. ...
   ```

   `d` montre `Last State: Terminated, Reason: Error, Exit Code: 1`. **Cause** : le Deployment ne fournit pas la variable `POSTGRES_PASSWORD` ; l'image officielle refuse d'initialiser une base sans mot de passe. Le Secret `postgres-credentials` existe pourtant (`:secrets`), il n'est simplement pas utilisé.

   Exemple de [`diagnostic.txt`](diagnostic.txt).

4. `:deploy`, sélectionner `postgres`, `e`, remplacer le bloc `env` par :

   ```yaml
             envFrom:
               - secretRef:
                   name: postgres-credentials
   ```

   Enregistrer : un nouveau Pod est créé (`:pods`), il devient `1/1`, puis l'API repasse `1/1` d'elle-même au bout de quelques secondes (PostgREST retente la connexion).

## Exercice 4

En lecture seule, les actions de modification (`Ctrl-d`, `e`, `s`…) sont désactivées et n'apparaissent plus dans l'en-tête. Utile pour observer un cluster de production sans risque de fausse manipulation (ce n'est pas une protection de sécurité : seules les permissions RBAC le sont).
