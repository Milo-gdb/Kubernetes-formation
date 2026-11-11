# Chapitre 06 — Ingress : exposer ses applications en HTTP

> **Objectifs** : publier plusieurs applications HTTP derrière un point d'entrée unique, avec un routage par nom d'hôte et par chemin, et un domaine local.
>
> **Durée estimée** : 2 h — **Mini-leçon associée** : [contrôleurs Ingress nginx](mini-lecon-nginx-ingress.md) — **Fil rouge** : `http://task-manager.local`.

---

## 1. Pourquoi l'Ingress ?

Avec les Services, on sait exposer une application à l'extérieur via un NodePort (`:30080`) ou un LoadBalancer (une IP par Service). Mais pour 10 applications web, on ne veut ni 10 ports exotiques ni 10 IP publiques : on veut **une seule entrée HTTP(S)** sur les ports 80/443, qui aiguille selon le **nom de domaine** et le **chemin** — exactement le reverse proxy du chapitre 01.

```text
                                   ┌──► Service frontend ──► Pods frontend
http://task-manager.local ─┐       │
                           ├──► Contrôleur Ingress (Traefik, :80/:443)
http://api.task-manager.local ┘    │
                                   └──► Service api ──► Pods api
```

## 2. Deux pièces distinctes

| Pièce | Rôle | Qui la fournit |
|---|---|---|
| **Ressource Ingress** | Des **règles** déclaratives : « tel hôte + tel chemin → tel Service:port ». Ce n'est qu'un objet stocké dans l'API. | Toi (YAML) |
| **Contrôleur Ingress** | Un **reverse proxy** qui tourne dans le cluster, surveille les ressources Ingress et se reconfigure en conséquence. | L'administrateur du cluster |

Sans contrôleur, une ressource Ingress **ne fait rien**. Kubernetes ne fournit pas de contrôleur par défaut ; chaque distribution en propose un. **k3s installe Traefik.** Il en existe beaucoup d'autres : contrôleurs basés sur nginx, HAProxy, Envoy (Contour, Emissary), Cilium… → voir la [mini-leçon](mini-lecon-nginx-ingress.md).

Le lien entre une ressource et un contrôleur se fait par l'**IngressClass** :

```bash
kubectl get ingressclass
# NAME      CONTROLLER                      
# traefik   traefik.io/ingress-controller   
```

## 3. Anatomie d'une ressource Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo
spec:
  ingressClassName: traefik          # quel contrôleur doit appliquer ces règles
  rules:
    - host: demo.local               # routage par nom d'hôte (en-tête Host)
      http:
        paths:
          - path: /a                 # routage par chemin
            pathType: Prefix
            backend:
              service:
                name: app-a
                port:
                  number: 80
          - path: /b
            pathType: Prefix
            backend:
              service:
                name: app-b
                port:
                  number: 80
```

### `pathType`

| Valeur | Comportement |
|---|---|
| `Prefix` | Correspond au préfixe, découpé par `/` : `/a` correspond à `/a`, `/a/`, `/a/x`, mais **pas** à `/abc`. |
| `Exact` | Correspond uniquement au chemin exact. |
| `ImplementationSpecific` | Laisse l'interprétation au contrôleur (expressions régulières, par exemple). |

Si plusieurs chemins correspondent, **le plus long l'emporte**.

!!! warning "Le chemin est transmis tel quel"
    Une requête vers `/a/page` arrive au backend avec le chemin `/a/page`. Si l'application attend `/page`, il faut une **réécriture** de chemin — et celle-ci n'est pas standardisée : annotations pour les contrôleurs nginx, ressource `Middleware` (StripPrefix) pour Traefik. C'est une des raisons de préférer le **routage par hôte** quand c'est possible, et l'une des motivations de la future **Gateway API**.

### TLS

```yaml
spec:
  tls:
    - hosts: [task-manager.local]
      secretName: task-manager-tls    # Secret de type kubernetes.io/tls (certificat + clé)
```

En production, **cert-manager** obtient et renouvelle automatiquement ces certificats (Let's Encrypt…).

## 4. Un domaine local pour les tests

Pour tester `http://task-manager.local` sans DNS public, on fait pointer le nom vers l'IP du nœud dans le fichier `/etc/hosts` de **la machine qui ouvre le navigateur** :

```bash
kubectl get ingress -A          # colonne ADDRESS = IP où écoute le contrôleur
echo "192.168.56.10  task-manager.local api.task-manager.local" | sudo tee -a /etc/hosts
curl http://task-manager.local
```

Sans toucher à `/etc/hosts`, on peut aussi forcer la résolution pour une seule commande :

```bash
curl --resolve task-manager.local:80:192.168.56.10 http://task-manager.local/
curl -H "Host: task-manager.local" http://192.168.56.10/
```

!!! tip "Et nip.io ?"
    Des services DNS publics comme `nip.io` résolvent `app.192.168.56.10.nip.io` en `192.168.56.10` : pratique pour éviter `/etc/hosts`.

## 5. Diagnostiquer

```bash
kubectl describe ingress task-manager -n task-manager   # règles + backends résolus
kubectl get endpointslices -n task-manager               # les Services visés ont-ils des Pods ?
kubectl logs -n kube-system deploy/traefik               # journaux du contrôleur
```

| Symptôme | Cause probable |
|---|---|
| `404 page not found` (Traefik) | Aucune règle ne correspond à l'hôte/chemin demandé, ou mauvaise `ingressClassName`. |
| `502 Bad Gateway` / `503` | La règle correspond, mais le Service n'a pas d'endpoint prêt ou le port est faux. |
| Délai dépassé | Le nom ne résout pas vers le nœud, pare-feu, contrôleur absent. |

## 6. Fil rouge : task-manager.local

On ajoute une ressource Ingress avec deux hôtes :

- `task-manager.local` → Service `frontend:80` ;
- `api.task-manager.local` → Service `api:3000`.

Manifeste : [`fil-rouge/06-ingress/50-ingress.yaml`](../fil-rouge/06-ingress/50-ingress.yaml). Le Service `frontend` peut rester en NodePort, mais l'Ingress devient l'entrée normale. Au chapitre 07, le frontend relaiera lui-même `/api/` vers l'API (reverse proxy nginx), ce qui évitera toute réécriture de chemin dans l'Ingress.

---

## Vocabulaire

| Terme | Définition |
|---|---|
| **Ingress** | Ressource décrivant des règles de routage HTTP(S) vers des Services. |
| **Contrôleur Ingress** | Reverse proxy du cluster qui applique les ressources Ingress. |
| **IngressClass** | Objet qui associe des ressources Ingress à un contrôleur donné. |
| **Traefik** | Reverse proxy cloud-native, contrôleur Ingress par défaut de k3s. |
| **Routage par hôte** | Choix du backend selon le nom de domaine demandé. |
| **Routage par chemin** | Choix du backend selon le début du chemin de l'URL. |
| **pathType** | Manière d'interpréter un chemin : Prefix, Exact, ImplementationSpecific. |
| **Terminaison TLS** | Déchiffrement HTTPS au niveau du proxy. |
| **cert-manager** | Opérateur qui automatise l'obtention et le renouvellement de certificats. |
| **Gateway API** | Successeur standardisé et plus expressif de l'API Ingress. |
| **/etc/hosts** | Fichier local de correspondances nom → IP, prioritaire sur le DNS. |
