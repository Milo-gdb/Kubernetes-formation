# Corrigé TD 09

```bash
kubectl create namespace td-09
kubectl apply -f td09.yaml
```

## Exercice 1

Après 30 s, `/tmp/sante` disparaît ; la sonde échoue 3 fois (15 s), le kubelet tue et **redémarre** le conteneur. Le redémarrage relance la commande, qui recrée le fichier… puis le supprime 30 s plus tard : le compteur RESTARTS augmente en boucle, avec un délai croissant (back-off).

```bash
kubectl describe pod vivant -n td-09 | grep -A10 Events
#  Warning  Unhealthy  ...  Liveness probe failed:
#  Normal   Killing    ...  Container busybox failed liveness probe, will be restarted
```

## Exercice 2

Sans `index.html`, nginx renvoie `403` sur `/` : la readinessProbe échoue, le Pod passe en `0/1 READY` et **disparaît des endpoints** ; le Service n'envoie plus de trafic qu'à l'autre Pod. Le Pod n'est **pas redémarré**… à condition que la liveness ne teste pas la même chose !

C'est pourquoi le corrigé utilise une liveness **`tcpSocket`** : nginx écoute toujours, le processus est vivant. Avec une liveness `httpGet /`, le conteneur serait redémarré (le système de fichiers repartant de l'image, `index.html` reviendrait) : ça « répare », mais on confond alors « vivant » et « prêt ».

```bash
POD=$(kubectl get pods -n td-09 -l app=web -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n td-09 $POD -- rm /usr/share/nginx/html/index.html
kubectl get pods -n td-09 -l app=web            # 0/1 pour ce Pod
kubectl get endpointslices -n td-09 -l kubernetes.io/service-name=web
kubectl delete pod -n td-09 $POD                # le Deployment recrée un Pod sain
```

## Exercice 3

```bash
kubectl get pod gourmand -n td-09          # OOMKilled puis CrashLoopBackOff
kubectl get pod gourmand -n td-09 -o jsonpath='{.status.containerStatuses[0].lastState.terminated}'
# {"exitCode":137,"reason":"OOMKilled",...}
```

137 = 128 + 9 : le processus a reçu le signal `SIGKILL` du noyau.

## Exercice 4

`garanti` : requests = limits pour CPU **et** mémoire → `Guaranteed`. Les Pods `web` (requests sans limite égale) → `Burstable`. `vivant` (aucune ressource) → `BestEffort`.

```bash
kubectl get pods -n td-09 -o custom-columns=NOM:.metadata.name,QOS:.status.qosClass
```

## Exercice 5

```bash
kubectl autoscale deployment web -n td-09 --cpu-percent=50 --min=2 --max=6   # ou le YAML du corrigé
kubectl get hpa web -n td-09
# NAME  REFERENCE       TARGETS       MINPODS  MAXPODS  REPLICAS
# web   Deployment/web  cpu: 2%/50%   2        6        2
```

Sous charge, l'utilisation dépasse largement 50 % de la request (50m) et le HPA monte jusqu'à 6 réplicas. `<unknown>` signifierait : pas de requests CPU, ou metrics-server indisponible (`kubectl top pods`).

## Exercice 6

```bash
kubectl apply -f fil-rouge/09-sondes-ressources/
kubectl get hpa -n task-manager
kubectl delete pod -n task-manager -l app=postgres
kubectl get pods -n task-manager -l app=api -w     # passent à 0/1 puis reviennent à 1/1
```
