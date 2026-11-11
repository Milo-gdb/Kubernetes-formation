# Chapitre 09 — Sondes, ressources et autoscaling

> **Objectifs** : indiquer à Kubernetes quand un conteneur est vivant et prêt, réserver et plafonner CPU et mémoire, et adapter automatiquement le nombre de réplicas à la charge.
>
> **Durée estimée** : 3 h — **Fil rouge** : un task-manager auto-réparateur et élastique.

---

## 1. « Running » ne veut pas dire « fonctionne »

Par défaut, le kubelet ne connaît qu'une chose : le **processus** principal du conteneur tourne-t-il ? Une application bloquée (interblocage, connexion perdue à la base) reste `Running` alors qu'elle ne répond plus. Et un Pod qui démarre reçoit du trafic dès que son processus est lancé, même s'il met 20 secondes à être opérationnel.

Les **sondes** (*probes*) permettent de décrire la santé réelle de l'application.

## 2. Les trois sondes

| Sonde | Question posée | En cas d'échec |
|---|---|---|
| **livenessProbe** | « Es-tu encore vivant ? » | Le kubelet **redémarre** le conteneur. |
| **readinessProbe** | « Es-tu prêt à recevoir du trafic ? » | Le Pod est **retiré des endpoints** des Services (pas de redémarrage). |
| **startupProbe** | « As-tu fini de démarrer ? » | Tant qu'elle n'a pas réussi, liveness et readiness sont suspendues ; après trop d'échecs, redémarrage. |

```text
démarrage ──► startupProbe OK ──► liveness + readiness actives en continu
                                   │                │
                       échec → redémarrage   échec → retiré du Service
```

### Les mécanismes

```yaml
livenessProbe:
  httpGet:                 # succès si code HTTP 200-399
    path: /live
    port: 3001
readinessProbe:
  tcpSocket:               # succès si la connexion TCP s'établit
    port: 5432
startupProbe:
  exec:                    # succès si la commande renvoie 0
    command: ["pg_isready"]
# Il existe aussi grpc: { port: ... }
```

### Les réglages temporels

| Champ | Défaut | Rôle |
|---|---|---|
| `initialDelaySeconds` | 0 | attente avant le premier test |
| `periodSeconds` | 10 | intervalle entre deux tests |
| `timeoutSeconds` | 1 | délai de réponse maximal |
| `failureThreshold` | 3 | échecs consécutifs avant de déclarer l'échec |
| `successThreshold` | 1 | succès consécutifs pour redevenir sain (readiness) |

Temps maximal de démarrage toléré par une startupProbe : `failureThreshold × periodSeconds`.

!!! warning "Les pièges classiques"
    - **Liveness trop agressive** : une application lente sous charge échoue à sa sonde, est redémarrée, la charge se reporte sur les autres… effet domino. Sois tolérant (`failureThreshold`, `timeoutSeconds`).
    - **Liveness qui teste les dépendances** : si la base tombe, redémarrer l'API ne sert à rien et aggrave la situation. La liveness teste le processus lui-même ; la **readiness** peut tenir compte des dépendances.
    - Une application longue à démarrer : utilise une **startupProbe** plutôt qu'un énorme `initialDelaySeconds`.

## 3. Requests et limits

Chaque conteneur peut déclarer :

```yaml
resources:
  requests:          # ce qui est RÉSERVÉ : utilisé par le scheduler
    cpu: 100m        # 100 millicores = 0,1 cœur
    memory: 128Mi
  limits:            # le PLAFOND : appliqué par le noyau (cgroups)
    cpu: 500m
    memory: 256Mi
```

| | requests | limits |
|---|---|---|
| **Utilisé par** | le **scheduler** : un Pod n'est placé que sur un nœud ayant assez de capacité **non réservée** | le **kubelet / le noyau** à l'exécution |
| **CPU** | part garantie du temps processeur | au-delà : le conteneur est **ralenti** (*throttling*), jamais tué |
| **Mémoire** | quantité réservée | au-delà : le conteneur est **tué** (`OOMKilled`, code 137) |

Unités : CPU en cœurs (`1`, `0.5`, `250m`) ; mémoire en octets avec suffixes binaires (`Mi`, `Gi`) ou décimaux (`M`, `G`). Attention : `128M` ≠ `128Mi`, et `128m` signifierait 0,128 octet !

```bash
kubectl describe node | grep -A8 "Allocated resources"   # réservations sur le nœud
kubectl top pods -n task-manager                          # consommation réelle (metrics-server)
```

!!! tip "Bonne pratique répandue"
    Toujours définir `requests` CPU et mémoire, et une `limits` **mémoire**. Beaucoup d'équipes évitent la limite CPU, dont le throttling dégrade la latence sans protéger grand-chose : la request CPU suffit à garantir une part équitable.

### Classes de qualité de service (QoS)

Kubernetes classe chaque Pod selon ses ressources ; en cas de manque de mémoire sur le nœud, les Pods sont **évincés** dans l'ordre inverse :

| Classe | Condition | Priorité de survie |
|---|---|---|
| **Guaranteed** | requests = limits pour CPU **et** mémoire, sur tous les conteneurs | la plus haute |
| **Burstable** | au moins une request ou limit, sans être Guaranteed | intermédiaire |
| **BestEffort** | aucune request ni limit | évincé en premier |

```bash
kubectl get pod <pod> -o jsonpath='{.status.qosClass}'
```

### Garde-fous par namespace

- **LimitRange** : valeurs par défaut et bornes min/max des requests/limits pour les conteneurs d'un namespace.
- **ResourceQuota** : plafond global d'un namespace (CPU, mémoire, nombre de Pods, de PVC…). Vu au chapitre 10.

## 4. L'autoscaling horizontal (HPA)

Le **HorizontalPodAutoscaler** ajuste le nombre de réplicas d'un Deployment (ou StatefulSet) pour maintenir une métrique autour d'une cible :

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  minReplicas: 2
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70     # 70 % de la request CPU, en moyenne
```

Raccourci : `kubectl autoscale deployment api --cpu-percent=70 --min=2 --max=5`.

Fonctionnement (toutes les 15 s environ) :

```text
réplicas souhaités = ceil( réplicas actuels × utilisation actuelle / utilisation cible )
   ex : 2 Pods à 140 % de leur request, cible 70 %  →  ceil(2 × 140 / 70) = 4 Pods
```

Prérequis :

1. **metrics-server** installé (fourni par k3s) — sinon la cible affiche `<unknown>` ;
2. des **requests** CPU sur les conteneurs : l'utilisation est un pourcentage de la request.

La réduction est volontairement lente (fenêtre de stabilisation de 5 minutes par défaut, réglable via `spec.behavior`) pour éviter le yo-yo.

!!! warning "HPA et champ replicas"
    Une fois un HPA en place, c'est lui qui pilote `spec.replicas`. Si tu réappliques un manifeste contenant `replicas: 3`, tu écrases temporairement sa décision. Dans un projet géré par HPA, on retire en général le champ `replicas` du manifeste (le chart Helm du chapitre 12 le fait quand l'autoscaling est activé).

### Et au-delà ?

- **VerticalPodAutoscaler (VPA)** : ajuste les requests/limits d'après la consommation observée (projet additionnel).
- **KEDA** : autoscaling sur événements (longueur d'une file de messages, requêtes Prometheus…), y compris jusqu'à zéro réplica.
- **Cluster Autoscaler / Karpenter** : ajoutent ou retirent des **nœuds** quand des Pods ne trouvent pas de place.

## 5. Fil rouge : santé, ressources et élasticité

[`fil-rouge/09-sondes-ressources/`](../fil-rouge/09-sondes-ressources/60-hpa.yaml) complète la version 08 :

| Composant | Sondes | Requests / limits | HPA |
|---|---|---|---|
| frontend | readiness + liveness HTTP `/` | 25m / 32Mi — limite 64Mi | 2 à 6 réplicas, cible 70 % CPU |
| api | readiness `/ready` + liveness `/live` (port d'administration PostgREST 3001) | 50m / 64Mi — limite 128Mi | 2 à 5 réplicas, cible 70 % CPU |
| postgres | readiness + liveness `pg_isready` | 100m / 128Mi — limite 512Mi | aucun : une base ne se réplique pas ainsi |

La readinessProbe de l'API est précieuse : quand PostgreSQL redémarre, PostgREST signale qu'il n'est plus prêt, il est retiré du Service, et le frontend ne relaie plus de requêtes vers une API incapable d'y répondre.

---

## Vocabulaire

| Terme | Définition |
|---|---|
| **livenessProbe** | Sonde de vie : en cas d'échec, le conteneur est redémarré. |
| **readinessProbe** | Sonde de disponibilité : en cas d'échec, le Pod est retiré des Services. |
| **startupProbe** | Sonde de démarrage qui suspend les autres sondes jusqu'à son succès. |
| **requests** | Ressources réservées pour un conteneur, utilisées pour le placement. |
| **limits** | Plafond de ressources appliqué à l'exécution. |
| **millicore (m)** | Millième de cœur CPU. |
| **Throttling** | Ralentissement d'un conteneur qui atteint sa limite CPU. |
| **OOMKilled** | Arrêt d'un conteneur ayant dépassé sa limite mémoire. |
| **QoS class** | Guaranteed, Burstable ou BestEffort : priorité face aux évictions. |
| **Éviction** | Arrêt de Pods par le kubelet pour libérer des ressources du nœud. |
| **metrics-server** | Agrégateur des métriques CPU/mémoire utilisé par `kubectl top` et le HPA. |
| **HPA** | HorizontalPodAutoscaler : adapte le nombre de réplicas à une métrique. |
| **LimitRange / ResourceQuota** | Bornes par conteneur / plafond global de ressources d'un namespace. |
