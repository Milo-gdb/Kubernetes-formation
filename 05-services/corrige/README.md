# Corrigé TD 05

```bash
kubectl create namespace td-05
kubectl apply -f whoami.yaml -f client.yaml
```

## Exercice 1

Voir [`whoami.yaml`](whoami.yaml) (Deployment + 3 Services).

```bash
kubectl get endpointslices -n td-05 -l kubernetes.io/service-name=whoami
kubectl get pods -n td-05 -o wide       # mêmes IP que les endpoints
kubectl port-forward -n td-05 svc/whoami 8080:80
```

`port-forward` vers un Service sélectionne **un** Pod au démarrage du tunnel : le Hostname ne change pas, c'est normal.

## Exercice 2

```bash
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
curl http://$NODE_IP:30500
```

## Exercice 3

`clusterIP: None` dans le Service `whoami-headless`.

## Exercice 4 — [`client.yaml`](client.yaml)

```bash
kubectl exec -n td-05 client -- nslookup whoami            # UNE adresse : la ClusterIP
kubectl exec -n td-05 client -- nslookup whoami-headless   # DEUX adresses : celles des Pods
for i in 1 2 3 4 5 6; do kubectl exec -n td-05 client -- wget -qO- http://whoami | grep Hostname; done
kubectl exec -n td-05 client -- nslookup api.task-manager
```

La répartition se fait **par connexion**, de façon aléatoire avec kube-proxy en mode iptables : sur quelques appels, on voit les deux Hostnames alterner irrégulièrement.

## Exercice 5

```bash
kubectl patch svc whoami -n td-05 -p '{"spec":{"selector":{"app":"whoam"}}}'
kubectl describe svc whoami -n td-05    # Endpoints: <none>
kubectl exec -n td-05 client -- wget -qO- -T 3 http://whoami   # échec : connexion refusée / délai dépassé
kubectl apply -f whoami.yaml            # rétablit le bon sélecteur
```

## Exercice 6

```bash
kubectl apply -f fil-rouge/05-services/
kubectl get svc,endpointslices -n task-manager
kubectl logs -n task-manager deploy/api | tail
```

Voir [`fil-rouge/05-services/40-services.yaml`](../../fil-rouge/05-services/40-services.yaml). L'API journalise désormais `Schema cache loaded` : elle a joint PostgreSQL par le nom DNS `postgres`.
