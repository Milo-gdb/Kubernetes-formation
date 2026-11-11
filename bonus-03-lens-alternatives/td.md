# TD Bonus 03 — Choisir et configurer une interface graphique

> Fichiers dans `~/formation-k8s/bonus03/`. Vérification : `./bonus-03-lens-alternatives/verifier.sh`

## Exercice 1 — Enquête

Pour **Lens Desktop**, **OpenLens**, **Freelens**, **Headlamp** et **Seabird**, trouve sur leurs dépôts ou sites officiels : la licence, la date de la dernière version, la nécessité ou non d'un compte. Consigne le résultat dans **`~/formation-k8s/bonus03/choix.md`** et termine par l'outil que tu recommanderais à ton équipe, avec ta justification.

## Exercice 2 — Un kubeconfig en lecture seule pour l'interface

1. Crée dans `kube-system` un ServiceAccount **`gui-lecture`** ayant le droit de **lire** le cluster (sans Secrets) et rien d'autre.
2. Construis le fichier **`~/formation-k8s/bonus03/kubeconfig-gui`** : même serveur et même autorité que ton kubeconfig actuel, authentification par un jeton de `gui-lecture` valable 24 h, contexte courant nommé **`formation-lecture`**. Droits du fichier : lecture/écriture pour toi seul.
3. Vérifie avec `kubectl --kubeconfig` qu'il permet de lister les Pods du fil rouge mais pas d'en supprimer.

## Exercice 3 — (sur un poste avec interface graphique) Freelens

Installe Freelens, ajoute le fichier `kubeconfig-gui`, et parcours le fil rouge : Pods, logs de l'API, events. Essaie de redimensionner le Deployment `frontend` : quel message obtiens-tu ? Compare l'expérience avec k9s et Headlamp.
