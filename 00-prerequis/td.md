# TD 00 — Prérequis

> Travaille dans `~/formation-k8s/ch00/` (crée-le avec `mkdir -p ~/formation-k8s/ch00`).
> Vérifie ton travail à tout moment avec : `./00-prerequis/verifier.sh`

## Exercice 1 — Ta machine est-elle prête ?

k3s demande au minimum **2 CPU**, **2 Go de RAM** et quelques Go de disque. Pour suivre toute la formation confortablement, prévois **10 Go libres**.

1. Affiche le nombre de CPU, la mémoire totale et l'espace disque libre de ta machine.
2. Si un critère n'est pas rempli, agrandis ta VM avant de continuer.

## Exercice 2 — Les outils de base

Vérifie que les commandes suivantes sont disponibles et installe celles qui manquent (`sudo apt install ...` sur Debian/Ubuntu) : `curl`, `git`, `ss` (paquet `iproute2`), `python3`, et un éditeur (`nano` ou `vim`).

## Exercice 3 — Écrire du YAML

Crée le fichier `~/formation-k8s/ch00/inventaire.yaml` qui décrit notre application fil rouge :

- une clé `application` valant `task-manager` ;
- une clé `composants` : une **liste** de 3 dictionnaires, chacun avec une clé `nom` et une clé `port` (entier) :
  - `frontend` sur le port 80,
  - `api` sur le port 3000,
  - `postgres` sur le port 5432.

Valide la syntaxe avec la commande donnée dans la leçon.

## Exercice 4 — Droits et scripts

1. Crée `~/formation-k8s/ch00/secret.txt` contenant n'importe quel texte, lisible et modifiable **uniquement par toi**.
2. Crée un script exécutable `~/formation-k8s/ch00/bonjour.sh` qui affiche exactement `Bonjour Kubernetes` quand on le lance avec `./bonjour.sh`.

## Exercice 5 — Réseau

1. Trouve l'adresse IP de ta **passerelle par défaut** et écris-la (seule) dans `~/formation-k8s/ch00/passerelle.txt`.
2. Vérifie que la résolution DNS fonctionne (`getent hosts kubernetes.io`).
3. Vérifie qu'aucun programme autre que k3s n'écoute déjà sur les ports **6443**, **80** et **443** (ils seront utilisés par le cluster).

## Pour aller plus loin

- Convertis `inventaire.yaml` en JSON avec `python3 -c 'import yaml,json,sys; print(json.dumps(yaml.safe_load(open(sys.argv[1])), indent=2))' inventaire.yaml`. Observe : YAML est un sur-ensemble de JSON.
- Que se passe-t-il si tu remplaces l'indentation d'une ligne par une tabulation ?
