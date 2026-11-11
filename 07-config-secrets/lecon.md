# Chapitre 07 — ConfigMaps et Secrets

> **Objectifs** : séparer la configuration du code, injecter des paramètres et des identifiants dans les Pods (variables d'environnement ou fichiers), et comprendre ce que les Secrets protègent… et ne protègent pas.
>
> **Durée estimée** : 2 h 30 — **Fil rouge** : plus aucun mot de passe en clair dans les Deployments.

---

## 1. Pourquoi externaliser la configuration ?

Une même image doit pouvoir tourner en développement, en recette et en production. Ce qui change d'un environnement à l'autre — adresse de la base, niveau de journalisation, mot de passe — ne doit donc **pas** être figé dans l'image, ni répété dans chaque manifeste de Deployment. C'est un principe des applications « twelve-factor » : *la configuration vit dans l'environnement*.

Kubernetes fournit deux objets pour cela :

| Objet | Contenu | Exemple |
|---|---|---|
| **ConfigMap** | Configuration **non sensible** | schéma exposé par l'API, fichier `nginx.conf`, script SQL d'initialisation |
| **Secret** | Données **sensibles** | mot de passe, jeton, clé TLS, identifiants de registre |

Les deux sont des dictionnaires clé → valeur, limités à 1 Mio, et **appartiennent à un namespace** : un Pod ne peut utiliser que ceux de son propre namespace.

## 2. Créer un ConfigMap

```bash
# À partir de valeurs littérales
kubectl create configmap api-config --from-literal=LOG_LEVEL=info --from-literal=PAGE_SIZE=20

# À partir d'un fichier : la clé est le nom du fichier, la valeur son contenu
kubectl create configmap frontend-nginx --from-file=default.conf

# Toujours utile : générer le YAML sans rien créer
kubectl create configmap demo --from-literal=a=1 --dry-run=client -o yaml
```

En YAML :

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-config
data:
  PGRST_DB_SCHEMAS: public          # les valeurs sont TOUJOURS des chaînes
  PGRST_DB_ANON_ROLE: web_anon
  PGRST_ADMIN_SERVER_PORT: "3001"   # guillemets obligatoires pour un nombre
  init.sql: |                       # une clé peut contenir un fichier entier
    CREATE TABLE tasks (...);
```

## 3. Consommer un ConfigMap

### Comme variables d'environnement

```yaml
containers:
  - name: api
    env:
      - name: LOG_LEVEL                 # une variable précise
        valueFrom:
          configMapKeyRef:
            name: api-config
            key: LOG_LEVEL
    envFrom:                            # toutes les clés d'un coup
      - configMapRef:
          name: api-config
```

### Comme fichiers (volume)

```yaml
containers:
  - name: nginx
    volumeMounts:
      - name: conf
        mountPath: /etc/nginx/conf.d    # chaque clé devient un fichier
        readOnly: true
volumes:
  - name: conf
    configMap:
      name: frontend-nginx
      # items:                          # facultatif : ne monter que certaines clés
      #   - key: default.conf
      #     path: default.conf
```

!!! warning "Mise à jour à chaud : pas toujours"
    | Mode | Si le ConfigMap change… |
    |---|---|
    | Volume | Les fichiers sont mis à jour dans le Pod après un délai pouvant atteindre une à deux minutes (sauf montage avec `subPath`). L'application doit encore **relire** le fichier. |
    | Variables d'environnement | **Rien ne change** : les variables sont figées au démarrage du conteneur. Il faut redémarrer les Pods : `kubectl rollout restart deployment/api`. |

    Le montage d'un volume **masque** le contenu existant du répertoire cible : monter un ConfigMap sur `/etc/nginx` ferait disparaître `nginx.conf` et `mime.types`. On monte donc sur un sous-répertoire dédié (`conf.d`) ou on utilise `subPath`.

## 4. Les Secrets

Un Secret se consomme **exactement comme un ConfigMap** (`secretKeyRef`, `secretRef`, volume `secret:`). La différence est dans le traitement :

```bash
kubectl create secret generic postgres-credentials \
  --from-literal=POSTGRES_USER=taskmanager \
  --from-literal=POSTGRES_PASSWORD='S3cr3t!'
kubectl get secret postgres-credentials -o yaml
```

```yaml
data:
  POSTGRES_PASSWORD: UzNjcjN0IQ==     # base64
  POSTGRES_USER: dGFza21hbmFnZXI=
```

En YAML, on peut écrire les valeurs en clair avec `stringData` ; l'API les convertit en base64 dans `data` :

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-credentials
type: Opaque
stringData:
  POSTGRES_PASSWORD: S3cr3t!
```

!!! danger "base64 n'est PAS du chiffrement"
    `echo UzNjcjN0IQ== | base64 -d` affiche le mot de passe. Le base64 sert uniquement à transporter des données binaires. Par défaut :

    - quiconque peut **lire** les Secrets d'un namespace (droit RBAC `get secrets`, chapitre 10) ou **créer un Pod** dans ce namespace peut récupérer leur contenu ;
    - les Secrets sont stockés **non chiffrés** dans etcd, sauf si le chiffrement au repos est activé (`k3s server --secrets-encryption`).

### Ce que les Secrets apportent malgré tout

- Un **type d'objet distinct**, donc des droits RBAC distincts : on peut autoriser la lecture des ConfigMaps et interdire celle des Secrets.
- Montés en volume, ils sont stockés en **mémoire (tmpfs)** sur le nœud, jamais sur disque, et seulement sur les nœuds qui en ont besoin.
- Ils sont masqués dans `kubectl describe`.

### Bonnes pratiques

1. Ne **jamais** committer un Secret en clair dans Git. Alternatives : **Sealed Secrets** (Secret chiffré déchiffrable seulement par le cluster), **SOPS**, **External Secrets Operator** (synchronisation depuis Vault, un gestionnaire cloud…).
2. Activer le chiffrement au repos d'etcd.
3. Restreindre `get/list/watch` sur les Secrets par RBAC.
4. Préférer le montage en fichiers aux variables d'environnement (celles-ci fuient plus facilement : journaux, rapports de plantage, `/proc`).

### Types de Secrets courants

| Type | Usage |
|---|---|
| `Opaque` | Données arbitraires (défaut). |
| `kubernetes.io/tls` | Certificat + clé (`tls.crt`, `tls.key`), utilisé par l'Ingress. |
| `kubernetes.io/dockerconfigjson` | Identifiants de registre, référencés par `imagePullSecrets`. |
| `kubernetes.io/service-account-token` | Jeton de ServiceAccount (historique). |

## 5. Les ConfigMaps et Secrets immuables

```yaml
immutable: true
```

Un objet immuable ne peut plus être modifié (seulement supprimé et recréé). Cela protège contre les modifications accidentelles et soulage l'API server, qui n'a plus besoin de surveiller les changements. Une stratégie courante consiste à suffixer le nom par une version (`api-config-v2`) : changer de version modifie le template du Deployment et déclenche un rolling update propre.

## 6. Fil rouge : configuration et identifiants externalisés

Dans [`fil-rouge/07-config-secrets/`](../fil-rouge/07-config-secrets/05-secrets.yaml) :

| Objet | Type | Contenu | Consommé par |
|---|---|---|---|
| `postgres-credentials` | Secret | utilisateur, mot de passe, base | PostgreSQL (`secretKeyRef`) |
| `api-db` | Secret | `PGRST_DB_URI` (contient le mot de passe) | API (`envFrom.secretRef`) |
| `api-config` | ConfigMap | schéma, rôle anonyme, port d'administration | API (`envFrom.configMapRef`) |
| `postgres-init` | ConfigMap | `01-schema.sql` : table `tasks`, rôle `web_anon` | PostgreSQL (volume sur `/docker-entrypoint-initdb.d`) |
| `frontend-nginx` | ConfigMap | `default.conf` : sert le HTML et relaie `/api/` vers `api:3000` | frontend (volume sur `/etc/nginx/conf.d`) |
| `frontend-html` | ConfigMap | `index.html` : l'interface du gestionnaire de tâches | frontend (volume) |

Résultat : `http://task-manager.local` affiche une vraie application qui liste, crée, termine et supprime des tâches.

!!! note "Une limite volontairement visible"
    Le Secret du fil rouge est écrit en clair (`stringData`) dans le dépôt pour que la formation fonctionne « clé en main ». C'est **exactement ce qu'il ne faut pas faire** sur un vrai projet ; le chapitre 12 montre comment le chart Helm génère le mot de passe à l'installation.

---

## Vocabulaire

| Terme | Définition |
|---|---|
| **ConfigMap** | Objet stockant de la configuration non sensible sous forme clé/valeur. |
| **Secret** | Objet destiné aux données sensibles, encodées en base64 et soumises à des droits distincts. |
| **base64** | Encodage réversible de données binaires en texte ; n'offre aucune confidentialité. |
| **stringData** | Champ d'écriture d'un Secret permettant de fournir les valeurs en clair. |
| **envFrom** | Injection de toutes les clés d'un ConfigMap/Secret comme variables d'environnement. |
| **configMapKeyRef / secretKeyRef** | Référence à une clé précise pour définir une variable d'environnement. |
| **subPath** | Montage d'un seul fichier d'un volume, sans masquer le répertoire cible (mais sans mise à jour à chaud). |
| **immutable** | Option empêchant toute modification d'un ConfigMap ou d'un Secret. |
| **Chiffrement au repos** | Chiffrement des Secrets dans etcd. |
| **Sealed Secrets / SOPS** | Outils permettant de versionner des Secrets chiffrés dans Git. |
| **imagePullSecrets** | Référence aux identifiants utilisés pour tirer des images d'un registre privé. |
