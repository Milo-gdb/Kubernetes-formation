# Corrigé TD 06

## Exercice 1

```bash
kubectl get ingressclass                  # traefik
kubectl get pods,svc -n kube-system -l app.kubernetes.io/name=traefik
```

Traefik tourne dans `kube-system`. Son Service est de type **LoadBalancer** : ServiceLB (Pods `svclb-traefik-*`) le publie sur les ports 80/443 de chaque nœud. L'IP de la colonne `EXTERNAL-IP` est celle du (des) nœud(s).

## Exercice 2 — [`apps.yaml`](apps.yaml), [`ingress-chemins.yaml`](ingress-chemins.yaml)

```bash
kubectl create namespace td-06
kubectl apply -f apps.yaml -f ingress-chemins.yaml
IP=$(kubectl get ingress chemins -n td-06 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl --resolve demo.local:80:$IP http://demo.local/a
curl --resolve demo.local:80:$IP http://demo.local/b
```

La ligne `GET /a HTTP/1.1` montre que le backend reçoit le chemin **complet** : l'Ingress standard ne réécrit pas.

## Exercice 3 — [`ingress-hotes.yaml`](ingress-hotes.yaml)

```bash
kubectl apply -f ingress-hotes.yaml
curl --resolve a.demo.local:80:$IP http://a.demo.local/
curl --resolve c.demo.local:80:$IP http://c.demo.local/    # 404 page not found
```

## Exercice 4

```bash
kubectl apply -f fil-rouge/06-ingress/
IP=$(kubectl get ingress task-manager -n task-manager -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "$IP task-manager.local api.task-manager.local" | sudo tee -a /etc/hosts
curl http://task-manager.local
curl http://api.task-manager.local/
```

Si ton navigateur tourne sur une autre machine que le nœud (VM), c'est dans **son** `/etc/hosts` (ou `C:\Windows\System32\drivers\etc\hosts`) qu'il faut ajouter la ligne, avec l'IP de la VM joignable depuis cette machine.

Voir [`fil-rouge/06-ingress/50-ingress.yaml`](../../fil-rouge/06-ingress/50-ingress.yaml).
