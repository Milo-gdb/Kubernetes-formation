# Chapitre 00 — Prérequis : Linux, YAML et réseau

> **Objectifs** : être à l'aise avec le terminal Linux, savoir lire et écrire du YAML sans erreur d'indentation, et comprendre les notions réseau (IP, ports, DNS, routage) que Kubernetes utilise en permanence.
>
> **Durée estimée** : 2 h

Kubernetes n'invente presque rien : il **assemble** des briques que tu connais peut-être déjà — des processus Linux isolés, des fichiers de configuration texte, des adresses IP et des ports. Avant d'empiler une couche d'abstraction, on vérifie que les fondations sont solides.

---

## 1. Linux : le système sur lequel tout repose

Un nœud Kubernetes est (dans l'immense majorité des cas) une machine Linux. Les conteneurs ne sont rien d'autre que des **processus Linux** auxquels le noyau applique des restrictions. Savoir naviguer dans ce système est donc indispensable pour diagnostiquer un problème.

### 1.1 Les commandes à connaître par cœur

| Besoin | Commande | Exemple |
|---|---|---|
| Où suis-je ? | `pwd` | `/home/milo` |
| Lister (avec fichiers cachés et droits) | `ls -la` | |
| Se déplacer | `cd` | `cd ~/formation-k8s` |
| Créer un dossier (et ses parents) | `mkdir -p` | `mkdir -p a/b/c` |
| Lire un fichier | `cat`, `less` | `less /etc/hosts` |
| Suivre un fichier qui grossit | `tail -f` | `tail -f /var/log/syslog` |
| Chercher du texte | `grep` | `grep -r "image:" .` |
| Voir les processus | `ps aux`, `top` | `ps aux \| grep containerd` |
| Gérer un service systemd | `systemctl` | `sudo systemctl status k3s` |
| Lire les journaux d'un service | `journalctl` | `sudo journalctl -u k3s -f` |
| Espace disque / mémoire | `df -h`, `free -h` | |

### 1.2 Utilisateurs, droits et `sudo`

Chaque fichier appartient à un **utilisateur** et à un **groupe**, et porte trois triplets de droits : propriétaire / groupe / autres, chacun pouvant être `r` (lecture), `w` (écriture), `x` (exécution).

```text
-rw------- 1 milo milo 2957 nov. 11 10:00 /home/milo/.kube/config
 │└┬┘└┬┘└┬┘
 │ │  │  └── autres : aucun droit
 │ │  └───── groupe : aucun droit
 │ └──────── propriétaire : lecture + écriture
 └────────── type : fichier ordinaire
```

On modifie les droits avec `chmod` (`chmod 600 fichier`, `chmod +x script.sh`) et le propriétaire avec `chown`.

!!! warning "Pourquoi c'est important pour Kubernetes"
    Le fichier **kubeconfig** (`~/.kube/config`) contient des identifiants administrateur du cluster. S'il est lisible par tout le monde, n'importe quel utilisateur de la machine devient administrateur du cluster. On le protège donc en `600`.

`sudo` permet d'exécuter une commande avec les droits de `root`. Installer k3s, lire les journaux système ou manipuler containerd directement le nécessitent.

### 1.3 Variables d'environnement

Une variable d'environnement est une paire `NOM=valeur` transmise à un processus. Les conteneurs reçoivent très souvent leur configuration par ce biais (on le verra avec les ConfigMaps et Secrets).

```bash
export KUBECONFIG=~/.kube/config   # définir
echo "$KUBECONFIG"                 # lire
env | grep KUBE                    # lister
```

### 1.4 Scripts bash

Un script bash est un fichier texte qui enchaîne des commandes. Il commence par un *shebang* et doit être exécutable :

```bash
#!/usr/bin/env bash
set -euo pipefail          # s'arrêter à la première erreur
echo "Bonjour $USER"
```

Les scripts `verifier.sh` de cette formation sont écrits ainsi : n'hésite pas à les lire, c'est un bon exercice.

---

## 2. YAML : la langue de Kubernetes

Tout objet Kubernetes (Pod, Service, Deployment…) se décrit dans un fichier **YAML**. YAML est un format de sérialisation lisible par un humain : il représente des **dictionnaires** (clé → valeur), des **listes** et des **valeurs simples** (scalaires).

### 2.1 Les trois structures

```yaml
# Un dictionnaire (mapping) : des paires clé: valeur
nom: task-manager
version: 1.0
actif: true

# Une liste (séquence) : chaque élément commence par "- "
langages:
  - bash
  - yaml
  - sql

# Imbrication : une liste de dictionnaires
composants:
  - nom: frontend
    port: 80
  - nom: api
    port: 3000
```

### 2.2 Les règles qui piègent tout le monde

1. **L'indentation définit la structure.** On utilise des **espaces**, jamais de tabulations. Deux espaces par niveau est la convention Kubernetes.
2. **Un espace après les deux-points** : `port: 80` et non `port:80`.
3. **Les types sont devinés** : `80` est un entier, `"80"` une chaîne, `true`/`false` des booléens, `1.10` un nombre (attention aux versions !). En cas de doute, mets des guillemets.
4. **Plusieurs documents dans un fichier** sont séparés par `---`.
5. **Texte multiligne** : `|` conserve les retours à la ligne, `>` les replie en espaces.

```yaml
script: |
  echo "ligne 1"
  echo "ligne 2"
---
# second document dans le même fichier
description: >
  Ce texte sera
  sur une seule ligne.
```

!!! tip "Valider un fichier YAML"
    `python3 -c 'import yaml,sys; list(yaml.safe_load_all(open(sys.argv[1])))' fichier.yaml`
    ne dit rien si le fichier est valide et affiche la ligne fautive sinon. Plus tard, `kubectl apply --dry-run=client -f fichier.yaml` vérifiera aussi la conformité au schéma Kubernetes.

### 2.3 Lire un manifeste Kubernetes

Presque tous les objets Kubernetes ont la même ossature à 4 champs :

```yaml
apiVersion: v1          # version de l'API qui définit ce type d'objet
kind: Pod               # le type d'objet
metadata:               # identité : nom, namespace, labels...
  name: exemple
spec:                   # l'état DÉSIRÉ, décrit par toi
  containers:
    - name: web
      image: nginx:1.30-alpine
```

Kubernetes ajoutera lui-même un 5ᵉ bloc, `status`, qui décrit l'état **observé**. Toute la philosophie de Kubernetes tient dans l'écart entre `spec` et `status` : des contrôleurs travaillent sans relâche pour rapprocher l'observé du désiré.

---

## 3. Réseau : les notions minimales

Kubernetes est avant tout un système **distribué** : des dizaines de composants se parlent en permanence par le réseau.

### 3.1 Adresses IP et sous-réseaux

Une adresse IPv4 (`192.168.1.20`) identifie une interface réseau. Un **sous-réseau** se note en CIDR : `10.42.0.0/16` signifie « toutes les adresses dont les 16 premiers bits valent ceux de 10.42 », soit 65 536 adresses.

k3s utilise par défaut :

| Plage | Usage |
|---|---|
| `10.42.0.0/16` | adresses des **Pods** |
| `10.43.0.0/16` | adresses virtuelles des **Services** |

Il faut donc que ton réseau local n'utilise pas déjà ces plages.

```bash
ip -brief address     # mes interfaces et leurs IP
ip route              # ma table de routage ; "default via X" = ma passerelle
```

### 3.2 Ports et protocoles

Une IP désigne une machine ; un **port** (0-65535) désigne un programme sur cette machine. TCP garantit la livraison ordonnée (HTTP, PostgreSQL), UDP ne garantit rien mais est plus léger (DNS).

Ports utiles dans cette formation :

| Port | Service |
|---|---|
| 6443/TCP | API Kubernetes (k3s) |
| 80, 443/TCP | HTTP(S) via l'Ingress |
| 10250/TCP | kubelet |
| 8472/UDP | réseau overlay Flannel (VXLAN) entre nœuds |
| 30000-32767/TCP | plage des Services NodePort |

```bash
ss -tlnp          # qui écoute sur quel port TCP ?
curl -v http://localhost:8080   # tester un service HTTP
```

### 3.3 DNS

Le DNS traduit un nom (`kubernetes.io`) en adresse IP. Sous Linux, la résolution passe par `/etc/hosts` (fichier local, prioritaire) puis par les serveurs listés dans `/etc/resolv.conf`.

Kubernetes embarque son propre serveur DNS (**CoreDNS**) : chaque Service obtient un nom du type `api.task-manager.svc.cluster.local`. Et pour nos tests, on ajoutera des noms locaux comme `task-manager.local` dans `/etc/hosts`.

```bash
getent hosts kubernetes.io   # résoudre comme le ferait une application
cat /etc/resolv.conf
```

### 3.4 HTTP en deux minutes

HTTP est un protocole requête/réponse. Une requête contient une **méthode** (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`), un **chemin** (`/api/tasks`), des **en-têtes** (dont `Host`, crucial pour l'Ingress) et éventuellement un corps. La réponse porte un **code de statut** : `2xx` succès, `3xx` redirection, `4xx` erreur du client, `5xx` erreur du serveur (`502 Bad Gateway` = le proxy n'a pas pu joindre l'application derrière lui).

```bash
curl -i http://example.com                       # voir les en-têtes de réponse
curl -H "Host: task-manager.local" http://IP/    # forcer l'en-tête Host
```

---

## 4. Préparer ton espace de travail

Tous les exercices de la formation se font dans un dossier personnel :

```bash
mkdir -p ~/formation-k8s
```

Les scripts de vérification y chercheront tes fichiers (tu peux changer ce chemin avec la variable `FORMATION_DIR`).

---

## Vocabulaire

| Terme | Définition |
|---|---|
| **Shell / bash** | Programme qui interprète les commandes tapées dans le terminal. |
| **systemd / service** | Gestionnaire qui démarre et surveille les programmes de fond (k3s en est un). |
| **Droits (permissions)** | Lecture/écriture/exécution accordées au propriétaire, au groupe et aux autres. |
| **Variable d'environnement** | Paire `NOM=valeur` transmise à un processus au démarrage. |
| **YAML** | Format texte de description de données basé sur l'indentation. |
| **Manifeste** | Fichier YAML décrivant un ou plusieurs objets Kubernetes. |
| **spec / status** | État désiré (écrit par toi) / état observé (écrit par Kubernetes). |
| **CIDR** | Notation d'un sous-réseau, ex. `10.42.0.0/16`. |
| **Port** | Numéro qui identifie un programme à l'écoute sur une machine. |
| **DNS** | Système qui traduit les noms en adresses IP. |
| **Passerelle (gateway)** | Routeur vers lequel part le trafic qui ne vise pas le réseau local. |
| **Code HTTP** | Nombre à 3 chiffres résumant le résultat d'une requête HTTP. |
