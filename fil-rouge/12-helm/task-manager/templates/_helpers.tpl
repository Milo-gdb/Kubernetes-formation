{{/* Nom complet : <release> si elle contient déjà le nom du chart, sinon <release>-<chart>. */}}
{{- define "task-manager.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/* Labels communs recommandés (app.kubernetes.io/*). */}}
{{- define "task-manager.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{/* Sélecteur d'un composant : include "task-manager.selector" (dict "ctx" . "composant" "api") */}}
{{- define "task-manager.selector" -}}
app.kubernetes.io/name: {{ .ctx.Chart.Name }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .composant }}
{{- end -}}

{{/* Mot de passe : valeur fournie, sinon celle du Secret existant, sinon aléatoire. */}}
{{- define "task-manager.password" -}}
{{- if .Values.postgres.password -}}
{{- .Values.postgres.password -}}
{{- else -}}
{{- $existant := lookup "v1" "Secret" .Release.Namespace (printf "%s-postgres" (include "task-manager.fullname" .)) -}}
{{- if and $existant $existant.data (hasKey $existant.data "POSTGRES_PASSWORD") -}}
{{- index $existant.data "POSTGRES_PASSWORD" | b64dec -}}
{{- else -}}
{{- randAlphaNum 24 -}}
{{- end -}}
{{- end -}}
{{- end -}}
