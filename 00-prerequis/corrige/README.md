# Corrigé TD 00

## Exercice 1

```bash
nproc                 # nombre de CPU
free -h               # mémoire
df -h ~               # espace disque de la partition contenant ton dossier personnel
```

## Exercice 2

```bash
for c in curl git ss python3 nano vim; do command -v $c >/dev/null && echo "OK $c" || echo "MANQUE $c"; done
sudo apt update && sudo apt install -y curl git iproute2 python3 python3-yaml nano
```

## Exercice 3

Voir [`inventaire.yaml`](inventaire.yaml). Points d'attention : deux espaces d'indentation, un tiret par élément de liste, et des ports **sans guillemets** pour qu'ils soient lus comme des entiers.

```bash
python3 -c 'import yaml,sys; print(yaml.safe_load(open(sys.argv[1])))' ~/formation-k8s/ch00/inventaire.yaml
```

## Exercice 4

```bash
cd ~/formation-k8s/ch00
echo "mot de passe ultra secret" > secret.txt
chmod 600 secret.txt          # rw------- : seul le propriétaire lit et écrit

cp /chemin/vers/le/repo/00-prerequis/corrige/bonjour.sh .   # ou écris-le toi-même
chmod +x bonjour.sh
./bonjour.sh
```

Voir [`bonjour.sh`](bonjour.sh).

## Exercice 5

```bash
ip route | awk '/^default/ {print $3; exit}' > ~/formation-k8s/ch00/passerelle.txt
getent hosts kubernetes.io
sudo ss -tlnp | grep -E ':(6443|80|443)\s'   # aucune ligne = ports libres
```

La passerelle est l'adresse après `default via` dans `ip route`. Si `ss` montre un Apache ou un nginx déjà installé sur le port 80, arrête-le (`sudo systemctl disable --now apache2`) : sinon l'Ingress de k3s ne pourra pas écouter.
