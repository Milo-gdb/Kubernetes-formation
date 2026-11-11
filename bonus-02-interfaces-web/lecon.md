# Bonus 02 — Interfaces web : Headlamp et Kubernetes Dashboard

> **Objectifs** : installer une interface web de gestion du cluster, s'y authentifier avec un jeton de ServiceAccount aux droits limités, l'exposer proprement, et connaître les limites de ces outils.
>
> **Durée estimée** : 1 h 30 — **Prérequis** : chapitres 05, 06, 10 (RBAC) et 12 (Helm).

---

## 1. À quoi sert une interface web ?

Une interface web affiche le cluster dans un navigateur : listes de ressources, graphiques de consommation, logs, events, édition de YAML, shell dans les conteneurs. Elle est précieuse pour :

- **découvrir** Kubernetes et visualiser les liens entre objets ;
- donner une **vue en lecture** à une équipe qui n'utilise pas kubectl ;
- **diagnostiquer** rapidement (logs, events) sans installer d'outil sur le poste.

Elle ne remplace pas les manifestes versionnés : toute modification faite « à la souris » est invisible dans Git et sera écrasée au prochain `kubectl apply`, `helm upgrade` ou synchronisation GitOps.

## 2. Deux modes de fonctionnement

| Mode | Principe | Authentification |
|---|---|---|
| **Dans le cluster** (*in-cluster*) | un Pod sert l'interface, exposé par un Service / Ingress | jeton (ServiceAccount) ou OIDC saisi dans le navigateur |
| **Application de bureau** | programme local qui lit ton kubeconfig | celle du kubeconfig |

## 3. Headlamp

**Headlamp** est une interface web **100 % open source** (licence Apache-2.0), aujourd'hui développée sous l'égide du projet Kubernetes (`kubernetes-sigs/headlamp`, rattaché au SIG UI) et donc de la **CNCF**. Elle fonctionne dans le cluster **ou** comme application de bureau (Linux, macOS, Windows), gère plusieurs clusters, et s'étend par **plugins** (Prometheus, Flux, cert-manager…).

### Installation dans le cluster (Helm)

```bash
helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/
helm repo update
helm install headlamp headlamp/headlamp -n headlamp --create-namespace
kubectl port-forward -n headlamp svc/headlamp 8080:80
# → http://localhost:8080
```

Headlamp demande un **jeton**. Le chart crée un ServiceAccount `headlamp` lié par défaut au rôle **`cluster-admin`** (ClusterRoleBinding `headlamp-admin`) : un jeton de ce compte donne **tous les droits**. En formation c'est pratique, mais la bonne pratique est de créer des comptes dédiés aux droits minimaux (chapitre 10) :

```bash
kubectl create serviceaccount observateur -n headlamp
kubectl create clusterrolebinding observateur-view --clusterrole=view --serviceaccount=headlamp:observateur
kubectl create token observateur -n headlamp --duration=8h
```

Connecté avec ce jeton, l'interface montre tout mais refuse les modifications : **l'interface ne fait qu'appliquer le RBAC du jeton**. Le rôle `view` ne donne pas accès aux Secrets.

### Application de bureau

Téléchargeable sur headlamp.dev (AppImage, `.deb`, Flatpak, Homebrew, winget…). Elle lit `~/.kube/config` et n'a besoin de rien dans le cluster.

## 4. Kubernetes Dashboard

Le **Kubernetes Dashboard** a été pendant des années l'interface web « officielle » du projet. **Son dépôt est désormais archivé et n'est plus maintenu** faute de mainteneurs ; son README recommande d'utiliser Headlamp à la place, et son ancien dépôt Helm ne répond plus. Tu le croiseras encore dans de nombreux tutoriels et clusters existants : il faut savoir le reconnaître, pas le déployer sur un nouveau cluster.

Pour l'étudier en TD, la dernière version « tout-en-un » (2.7.0) s'installe encore avec un manifeste :

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 8443:443
# → https://localhost:8443 (certificat auto-signé), connexion par jeton
```

!!! danger "Un dashboard exposé est une porte d'entrée"
    Des clusters ont été compromis via un Dashboard exposé sur Internet avec un compte trop privilégié (attaques de minage de cryptomonnaie). Règles : jamais d'exposition publique sans authentification forte, jamais de compte `cluster-admin` par défaut, accès par `port-forward` ou VPN, et suppression quand on ne s'en sert plus.

## 5. Exposer Headlamp par un Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: headlamp
  namespace: headlamp
spec:
  ingressClassName: traefik
  rules:
    - host: headlamp.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: headlamp
                port:
                  number: 80
```

En dehors d'un poste de formation, ajoute TLS (cert-manager) et une authentification OIDC (Headlamp sait déléguer la connexion à un fournisseur d'identité : Keycloak, Dex, Google…).

## 6. Comparaison

| Critère | Headlamp | Kubernetes Dashboard |
|---|---|---|
| Licence | Apache-2.0 | Apache-2.0 |
| État | **activement maintenu** (kubernetes-sigs) | **archivé**, plus de correctifs |
| Modes | dans le cluster **et** application de bureau | dans le cluster uniquement |
| Multi-clusters | oui | non |
| Extensibilité | plugins | non |
| Authentification | jeton, OIDC, kubeconfig (bureau) | jeton, kubeconfig |
| Métriques | via metrics-server, Prometheus en plugin | via metrics-scraper |
| Ressources personnalisées (CRD) | oui | limité |

## 7. Limites communes

- Elles n'apportent **aucun droit** : tout passe par le RBAC du jeton.
- Les modifications manuelles **dérivent** de la configuration versionnée.
- L'**historique** est limité à ce que garde l'API (events d'environ une heure) : pour un vrai historique, il faut une pile d'observabilité (Prometheus, Loki…).
- Un composant de plus à **maintenir et sécuriser** dans le cluster.
- Pour le travail quotidien, beaucoup préfèrent k9s (bonus 01) ou une application de bureau (bonus 03).

---

## Vocabulaire

| Terme | Définition |
|---|---|
| **Headlamp** | Interface web et de bureau open source pour Kubernetes, projet kubernetes-sigs. |
| **Kubernetes Dashboard** | Ancienne interface web officielle, dépôt archivé. |
| **In-cluster** | Mode où l'outil tourne dans un Pod du cluster. |
| **Jeton de ServiceAccount** | Jeton (JWT) prouvant l'identité d'un ServiceAccount auprès de l'API. |
| **OIDC** | *OpenID Connect* : protocole de connexion déléguée à un fournisseur d'identité. |
| **Rôle `view`** | ClusterRole fourni par Kubernetes : lecture de la plupart des objets, sauf Secrets. |
| **Plugin** | Extension ajoutant des vues ou fonctions à Headlamp. |
| **Dérive de configuration** | Écart entre l'état du cluster et la configuration versionnée. |
