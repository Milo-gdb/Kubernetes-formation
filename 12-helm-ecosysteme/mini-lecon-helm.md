# Mini-leçon — Helm en profondeur

> Durée : 45 min. Prérequis : leçon du chapitre 12. Exemples tirés du chart [`fil-rouge/12-helm/task-manager`](../fil-rouge/12-helm/task-manager/Chart.yaml).

## 1. Comment Helm rend un chart

1. Il fusionne les valeurs (défauts du chart ← fichiers `-f` ← `--set`).
2. Il évalue chaque fichier de `templates/` (sauf ceux qui commencent par `_`) avec le moteur de templates de Go.
3. Il trie les objets (Namespaces, puis Secrets/ConfigMaps, puis Services, puis Deployments…) et les envoie à l'API.
4. Il enregistre la release (manifestes rendus + valeurs) dans un Secret de type `helm.sh/release.v1`.
5. Lors d'un `upgrade`, il compare l'**ancien manifeste, le nouveau et l'état réel** (*three-way merge*) pour décider des modifications.

```bash
kubectl get secrets -n tm-helm -l owner=helm
```

## 2. Les helpers et le contexte

```yaml
{{/* _helpers.tpl */}}
{{- define "task-manager.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
```

- `.` est le **contexte courant**. Dans un `range` ou un `with`, il change : on utilise alors `$` pour revenir à la racine (`$.Values`, `include "..." $`).
- `include` (contrairement à `template`) renvoie une chaîne que l'on peut chaîner : `include "x" . | nindent 4`.
- On passe plusieurs paramètres avec un dictionnaire : `include "task-manager.selector" (dict "ctx" . "composant" "api")`.
- Les noms Kubernetes sont limités à 63 caractères (labels DNS) : d'où `trunc 63`.

## 3. Fonctions utiles

| Fonction | Exemple |
|---|---|
| `default` | `{{ .Values.image.tag \| default .Chart.AppVersion }}` |
| `required` | `{{ required "ingress.host est obligatoire" .Values.ingress.host }}` |
| `quote` | `{{ .Values.port \| quote }}` → `"3000"` |
| `toYaml` + `nindent` | insérer un bloc YAML de valeurs avec la bonne indentation |
| `tpl` | évaluer une chaîne comme un modèle (utilisé pour `files/default.conf`) |
| `.Files.Get` | inclure un fichier du chart (`files/01-schema.sql`) |
| `sha256sum` | calculer une empreinte (annotation `checksum/config`) |
| `randAlphaNum` | générer une chaîne aléatoire (mot de passe) |
| `lookup` | lire un objet existant dans le cluster |

### Le motif « mot de passe stable »

```yaml
{{- $existant := lookup "v1" "Secret" .Release.Namespace "task-manager-postgres" -}}
{{- if $existant -}}
  {{- index $existant.data "POSTGRES_PASSWORD" | b64dec -}}   {{/* on réutilise */}}
{{- else -}}
  {{- randAlphaNum 24 -}}                                      {{/* première installation */}}
{{- end -}}
```

Sans `lookup`, chaque `upgrade` générerait un nouveau mot de passe… que la base, déjà initialisée, ignorerait : l'API ne pourrait plus se connecter. Attention : `lookup` renvoie toujours un résultat vide avec `helm template` (pas d'accès au cluster).

### Le motif « redémarrer quand la configuration change »

```yaml
annotations:
  checksum/config: {{ include (print $.Template.BasePath "/configmaps.yaml") . | sha256sum }}
```

Un ConfigMap modifié ne redémarre pas les Pods (chapitre 07). Mais si son empreinte figure dans le template du Pod, le template change, donc le Deployment lance un rolling update.

## 4. Hooks

Des annotations transforment un objet en **hook**, exécuté à un moment précis du cycle de vie :

```yaml
metadata:
  annotations:
    "helm.sh/hook": pre-upgrade          # pre/post-install, pre/post-upgrade, pre/post-delete, pre/post-rollback, test
    "helm.sh/hook-weight": "0"
    "helm.sh/hook-delete-policy": hook-succeeded
```

Usage typique : un Job de **migration de schéma** en `pre-upgrade`, ou un Job de test lancé par `helm test`.

## 5. Dépendances

```yaml
# Chart.yaml
dependencies:
  - name: postgresql
    version: "16.x.x"
    repository: oci://registry-1.docker.io/bitnamicharts
    condition: postgresql.enabled
```

`helm dependency update` télécharge les sous-charts dans `charts/`. Les valeurs d'un sous-chart se passent sous sa clé : `postgresql.auth.password`. Le chart task-manager embarque volontairement son propre PostgreSQL pour rester lisible.

## 6. Valider les valeurs

Un fichier `values.schema.json` (JSON Schema) permet à Helm de refuser des valeurs invalides à l'installation (type, valeurs autorisées, champs obligatoires) avec un message clair.

## 7. Bonnes pratiques

- Documenter chaque valeur dans `values.yaml` (commentaires).
- Incrémenter `version` (le chart) à chaque modification, `appVersion` quand l'application change.
- Ne jamais mettre de secrets réels dans `values.yaml` : les fournir à l'installation, les générer, ou utiliser un gestionnaire de secrets.
- `helm lint` + `helm template` dans la CI ; outils complémentaires : `helm-unittest`, `ct` (chart-testing), `kubeconform`.
- Versionner un fichier de valeurs par environnement (`valeurs-recette.yaml`, `valeurs-prod.yaml`).

## Vocabulaire

| Terme | Définition |
|---|---|
| **Three-way merge** | Comparaison ancien manifeste / nouveau manifeste / état réel lors d'un upgrade. |
| **Contexte (`.`, `$`)** | Objet courant d'un template ; `$` désigne toujours la racine. |
| **Sprig** | Bibliothèque de fonctions de templates utilisée par Helm. |
| **lookup** | Fonction qui lit un objet existant du cluster pendant le rendu. |
| **Hook** | Objet exécuté à une étape précise du cycle de vie d'une release. |
| **Sous-chart** | Chart déclaré comme dépendance d'un autre chart. |
| **values.schema.json** | Schéma JSON validant les valeurs fournies à un chart. |
