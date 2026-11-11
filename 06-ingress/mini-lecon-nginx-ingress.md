# Mini-leçon — Les contrôleurs Ingress basés sur nginx

> Durée : 30 min. Prérequis : section 5 du chapitre 01 (reverse proxy nginx) et leçon du chapitre 06.

## Le principe

Un contrôleur Ingress « nginx » est un Pod qui contient **deux choses** :

1. un **programme contrôleur** qui surveille (watch) les objets Ingress, Services, EndpointSlices et Secrets via l'API ;
2. un **nginx** dont il **génère la configuration** à partir de ces objets, puis qu'il recharge.

```text
 API server ──watch──► contrôleur ──génère──► nginx.conf ──reload──► nginx (:80/:443)
  (Ingress, Services,                                                   │
   EndpointSlices)                                                      └──► Pods
```

La correspondance avec ce que tu as écrit à la main au chapitre 01 est directe :

| Ressource Ingress | Configuration nginx générée |
|---|---|
| `rules[].host` | `server { server_name ...; }` |
| `paths[].path` | `location /... { }` |
| `backend.service` | `proxy_pass` vers les IP des Pods (upstream) |
| `tls[]` | `listen 443 ssl; ssl_certificate ...;` |
| annotations | directives supplémentaires (réécriture, limites, CORS…) |

Détail notable : ces contrôleurs envoient en général le trafic **directement aux IP des Pods** (lues dans les EndpointSlices) plutôt qu'à la ClusterIP du Service, ce qui permet des fonctions comme l'affinité de session.

## Deux projets à ne pas confondre

| | **ingress-nginx** (communauté Kubernetes) | **NGINX Ingress Controller** (F5/NGINX) |
|---|---|---|
| Dépôt | `kubernetes/ingress-nginx` | `nginx/kubernetes-ingress` |
| Annotations | `nginx.ingress.kubernetes.io/...` | `nginx.org/...` + CRD `VirtualServer` |
| Statut | **Retiré** : maintenance arrêtée en mars 2026, dépôt archivé | Maintenu, open source (Apache 2.0) |

!!! danger "ingress-nginx est en fin de vie"
    Le contrôleur communautaire **ingress-nginx**, longtemps le plus utilisé, a été retiré par le projet Kubernetes : plus de correctifs, y compris de sécurité, depuis mars 2026. Il fonctionne encore, mais **on ne l'installe plus sur un nouveau cluster**. Les pistes recommandées sont la migration vers la **Gateway API** (avec une implémentation maintenue) ou vers un autre contrôleur Ingress maintenu (Traefik, NGINX Ingress Controller de F5, HAProxy, Contour…). C'est l'une des raisons pour lesquelles cette formation utilise **Traefik**, fourni et maintenu avec k3s.

## Les annotations : puissance et piège

Avec les contrôleurs nginx, presque toute la configuration avancée passe par des **annotations** sur l'objet Ingress. Exemple historique avec ingress-nginx — réécrire `/api/tasks` en `/tasks` :

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
    - host: task-manager.local
      http:
        paths:
          - path: /api(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service: { name: api, port: { number: 3000 } }
```

L'équivalent avec Traefik passe par une ressource `Middleware` :

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: strip-api
spec:
  stripPrefix:
    prefixes: ["/api"]
---
# puis, sur l'Ingress :
# metadata.annotations:
#   traefik.ingress.kubernetes.io/router.middlewares: task-manager-strip-api@kubernetescrd
```

Ces annotations **ne sont pas portables** d'un contrôleur à l'autre : changer de contrôleur oblige à les réécrire. Certaines annotations permettant d'injecter du nginx brut (`configuration-snippet`) ont en outre été à l'origine de failles de sécurité graves. C'est tout l'intérêt de la **Gateway API**, qui standardise ces besoins (réécriture, en-têtes, répartition pondérée…) dans des champs typés :

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: api
spec:
  parentRefs: [{ name: ma-gateway }]
  hostnames: ["task-manager.local"]
  rules:
    - matches: [{ path: { type: PathPrefix, value: /api } }]
      filters:
        - type: URLRewrite
          urlRewrite: { path: { type: ReplacePrefixMatch, replacePrefixMatch: / } }
      backendRefs: [{ name: api, port: 3000 }]
```

## Essayer un contrôleur nginx sur k3s (optionnel)

Traefik occupe déjà les ports 80/443 du nœud. Pour tester le **NGINX Ingress Controller** de F5 à côté, on peut l'installer avec Helm (chapitre 12) en Service NodePort :

```bash
helm install nginx-ingress oci://ghcr.io/nginx/charts/nginx-ingress \
  --namespace nginx-ingress --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.ingressClass.name=nginx
kubectl get ingressclass          # traefik et nginx
```

Une ressource Ingress avec `ingressClassName: nginx` sera alors servie par nginx (sur le NodePort affiché par `kubectl get svc -n nginx-ingress`), et celles en `traefik` par Traefik. Pour le désinstaller : `helm uninstall nginx-ingress -n nginx-ingress`.

## Vocabulaire

| Terme | Définition |
|---|---|
| **ingress-nginx** | Contrôleur Ingress communautaire basé sur nginx, retiré en 2026. |
| **NGINX Ingress Controller** | Contrôleur Ingress maintenu par F5/NGINX, distinct d'ingress-nginx. |
| **Annotation** | Métadonnée clé/valeur non sélectionnable, souvent lue par des contrôleurs pour des options. |
| **Réécriture (rewrite)** | Modification du chemin de la requête avant de la transmettre au backend. |
| **Middleware (Traefik)** | Ressource Traefik qui transforme une requête (réécriture, authentification…). |
| **Upstream** | Groupe de serveurs backend vers lesquels nginx relaie le trafic. |
| **Gateway API** | API standard (Gateway, HTTPRoute…) qui succède à Ingress avec des champs typés et portables. |
