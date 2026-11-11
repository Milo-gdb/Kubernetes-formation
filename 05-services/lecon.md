# Chapitre 05 — Services et DNS interne

> **Objectifs** : donner une adresse stable à un ensemble de Pods, comprendre les types de Services (ClusterIP, NodePort, LoadBalancer, headless) et utiliser le DNS interne du cluster.
>
> **Durée estimée** : 2 h 30 — **Fil rouge** : les trois briques se trouvent enfin par leur nom.

---

## 1. Le problème : des Pods éphémères

Chaque Pod reçoit une IP, mais cette IP **change** dès que le Pod est recréé (mise à jour, panne, mise à l'échelle). Et avec 3 réplicas, à laquelle des 3 IP s'adresser ? Coder des IP de Pods en dur est donc impossible.

Le **Service** résout ce problème : c'est une **adresse virtuelle stable** (IP + nom DNS) placée devant un **ensemble dynamique de Pods**, choisis par **sélecteur de labels**. Le trafic envoyé au Service est réparti entre les Pods prêts.

```text
                       Service "api"  (10.43.102.36:3000, DNS: api)
                         selector: app=api
                    ┌────────────┼────────────┐
                    ▼            ▼            ▼
             Pod api-a      Pod api-b     (Pod api-c en démarrage :
             10.42.0.12     10.42.0.15     pas encore prêt → exclu)
```

## 2. Comment ça marche

1. Tu crées un Service avec un `selector`.
2. Le contrôleur d'**EndpointSlices** liste en permanence les Pods qui correspondent au sélecteur **et sont prêts**, et écrit leurs IP dans des objets `EndpointSlice`.
3. Sur chaque nœud, **kube-proxy** traduit ces informations en règles réseau (iptables, nftables ou IPVS) : tout paquet vers l'IP du Service est redirigé vers l'IP d'un des Pods.
4. **CoreDNS** publie un nom DNS pour le Service.

L'IP d'un Service (ClusterIP) est **virtuelle** : aucune interface ne la porte, on ne peut pas la « pinguer ». Elle n'existe que dans les règles de kube-proxy.

```bash
kubectl get svc,endpointslices -n task-manager
kubectl describe svc api -n task-manager      # ligne "Endpoints:"
```

!!! tip "Le réflexe de diagnostic"
    Un Service qui ne répond pas ? Regarde d'abord ses **endpoints**. Liste vide = le sélecteur ne correspond à aucun Pod prêt (faute de frappe dans un label, Pods non prêts, mauvais namespace).

## 3. Anatomie d'un Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  type: ClusterIP          # valeur par défaut
  selector:
    app: api               # cible les Pods portant ce label
  ports:
    - name: http
      port: 3000           # port du SERVICE
      targetPort: http     # port du CONTENEUR (numéro ou nom du containerPort)
      protocol: TCP
```

`port` et `targetPort` peuvent différer : un Service peut exposer le port 80 vers des conteneurs qui écoutent sur 8080. Utiliser le **nom** du port (`targetPort: http`) permet de changer le numéro dans le Pod sans toucher au Service.

Raccourci impératif : `kubectl expose deployment api --port=3000 --target-port=3000`.

## 4. Les types de Services

| Type | Accessible depuis | Usage |
|---|---|---|
| **ClusterIP** | l'intérieur du cluster uniquement | communication entre microservices (API ↔ base) |
| **NodePort** | `<IP de n'importe quel nœud>:<30000-32767>` | accès externe simple, tests, labs |
| **LoadBalancer** | une IP externe fournie par l'infrastructure | exposition en production sur un cloud ; dans k3s, fourni par ServiceLB |
| **ExternalName** | — | alias DNS vers un nom externe (`CNAME`) |
| **Headless** (`clusterIP: None`) | — | pas d'IP virtuelle : le DNS renvoie directement les IP des Pods |

Chaque type **englobe** le précédent : un NodePort a aussi une ClusterIP, un LoadBalancer a aussi un NodePort.

```yaml
spec:
  type: NodePort
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080   # facultatif : sinon attribué automatiquement
```

!!! info "LoadBalancer dans k3s"
    Sur un cloud, un Service `LoadBalancer` provoque la création d'un répartiteur de charge chez le fournisseur. Dans k3s, **ServiceLB** déploie un petit Pod `svclb-*` sur chaque nœud qui écoute sur le port demandé et relaie vers le Service : l'« IP externe » est simplement celle du nœud. C'est ainsi que Traefik reçoit le trafic des ports 80/443.

## 5. Le DNS interne

CoreDNS crée automatiquement des enregistrements pour chaque Service :

```text
<service>.<namespace>.svc.cluster.local
   api   .task-manager.svc.cluster.local   →  10.43.102.36
```

Grâce aux domaines de recherche configurés dans le `/etc/resolv.conf` de chaque Pod, on peut abréger :

| Depuis un Pod du namespace… | Nom utilisable |
|---|---|
| `task-manager` | `api`, `api.task-manager`, `api.task-manager.svc.cluster.local` |
| un autre namespace | `api.task-manager` (ou le nom complet) |

Pour un Service **headless**, le nom renvoie la liste des IP des Pods prêts, et chaque Pod d'un StatefulSet obtient son propre nom (`postgres-0.postgres…`, chapitre 11).

```bash
kubectl run -it --rm dns-test --image=busybox:1.37 --restart=Never -- nslookup api.task-manager
```

## 6. Accéder à un Service pendant le développement

```bash
kubectl port-forward -n task-manager svc/frontend 8080:80   # http://localhost:8080
```

`port-forward` passe par l'API server : parfait pour déboguer, inadapté pour servir des utilisateurs.

## 7. Fil rouge : les Services du task-manager

| Service | Type | Port | Cible |
|---|---|---|---|
| `frontend` | NodePort (30080) | 80 | Pods `app=frontend` |
| `api` | ClusterIP | 3000 | Pods `app=api` |
| `postgres` | ClusterIP | 5432 | Pods `app=postgres` |

Le nom `postgres` utilisé dans la variable `PGRST_DB_URI` de l'API devient résolvable : l'API se connecte enfin à la base. Manifestes : [`fil-rouge/05-services/`](../fil-rouge/05-services/40-services.yaml).

---

## Vocabulaire

| Terme | Définition |
|---|---|
| **Service** | Point d'accès réseau stable (IP + DNS) vers un ensemble de Pods. |
| **ClusterIP** | IP virtuelle d'un Service, joignable uniquement dans le cluster. |
| **NodePort** | Port ouvert sur chaque nœud (30000-32767) qui redirige vers le Service. |
| **LoadBalancer** | Service exposé via un répartiteur de charge externe (ServiceLB dans k3s). |
| **Headless** | Service sans ClusterIP dont le DNS renvoie les IP des Pods. |
| **EndpointSlice** | Objet listant les adresses des Pods prêts derrière un Service. |
| **kube-proxy** | Composant qui programme les règles réseau des Services sur chaque nœud. |
| **port / targetPort** | Port exposé par le Service / port du conteneur visé. |
| **CoreDNS** | Serveur DNS du cluster. |
| **FQDN** | Nom de domaine complet, ex. `api.task-manager.svc.cluster.local`. |
