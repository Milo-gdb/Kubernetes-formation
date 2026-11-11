# Bonus 03 — Lens et les alternatives : panorama des interfaces graphiques

> **Objectifs** : connaître les principales interfaces graphiques pour Kubernetes, comprendre l'évolution de Lens et de ses licences, choisir un outil libre adapté, et lui fournir un kubeconfig aux droits limités.
>
> **Durée estimée** : 1 h — **Prérequis** : chapitre 10 (RBAC), bonus 01 et 02.

---

## 1. Trois familles d'outils

| Famille | Exemples | Où ça tourne |
|---|---|---|
| **Terminal (TUI)** | k9s (bonus 01) | ton terminal, local ou SSH |
| **Web dans le cluster** | Headlamp, Kubernetes Dashboard (bonus 02) | un Pod, consulté dans un navigateur |
| **Application de bureau (IDE Kubernetes)** | Lens, Freelens, OpenLens, Headlamp Desktop, Seabird, Aptakube… | ton poste, avec ton kubeconfig |

Toutes passent par l'**API Kubernetes** avec les identifiants qu'on leur donne : aucune ne contourne le RBAC.

## 2. L'histoire de Lens, honnêtement

**Lens** a popularisé l'« IDE Kubernetes » : une application de bureau (Electron) multi-clusters, avec métriques, terminal intégré et extensions. Créé en 2019 et racheté par **Mirantis** en 2020, il était alors entièrement open source (MIT).

Son modèle a ensuite changé par étapes :

1. Le code ouvert a été isolé dans un projet de base appelé **OpenLens** (dépôt `lensapp/lens`), tandis que le produit **Lens Desktop** distribué par Mirantis ajoutait des composants **propriétaires**.
2. Lens Desktop a introduit un **compte obligatoire (Lens ID)** et des **abonnements** : gratuit pour un usage personnel/éducatif et pour les petites structures, **payant** pour les entreprises au-delà d'un seuil (conditions à vérifier sur le site de l'éditeur, elles ont évolué plusieurs fois).
3. Des fonctions de la base libre ont été retirées (par exemple les menus de logs/shell des Pods, désormais fournis par des extensions communautaires).
4. Le code source de Lens a finalement été **fermé** : le dépôt `lensapp/lens` ne reçoit plus de mises à jour du produit, et le projet communautaire de construction **OpenLens** (`MuhammedKalkan/OpenLens`), qui publiait des binaires sans compte, prévient qu'il ne faut plus attendre de nouvelles versions.

**Conclusion** : Lens est aujourd'hui un logiciel **propriétaire au modèle freemium**. Il reste un bon produit, mais ce n'est plus un logiciel libre ; OpenLens est figé et ne doit plus être installé sur un poste qui accède à un cluster (pas de correctifs de sécurité).

## 3. Les alternatives libres

| Outil | Licence | Type | Points forts | Points d'attention |
|---|---|---|---|---|
| **Freelens** (`freelensapp/freelens`) | MIT | bureau | fork communautaire d'OpenLens, **interface familière pour les anciens utilisateurs de Lens**, sans compte, activement maintenu, extensions | même base Electron, un peu lourde |
| **Headlamp** (`kubernetes-sigs/headlamp`) | Apache-2.0 | bureau **et** web | projet Kubernetes/CNCF, plugins, multi-clusters, le même outil sur le poste et dans le cluster | moins de fonctions « IDE » que Lens |
| **k9s** (`derailed/k9s`) | Apache-2.0 | terminal | très rapide, léger, fonctionne en SSH, raccourcis puissants | courbe d'apprentissage du clavier |
| **Seabird** (`getseabird/seabird`) | MPL-2.0 | bureau (GTK) | application native légère, Linux d'abord | projet jeune, communauté réduite |
| **Kubernetes Dashboard** | Apache-2.0 | web | très répandu historiquement | **archivé** (bonus 02) |
| **Octant** (VMware) | Apache-2.0 | bureau/web | — | **archivé** depuis 2023, à éviter |

Outils propriétaires que tu croiseras aussi : **Lens Desktop** (freemium), **Aptakube** (payant), **Monokle** (orienté édition de manifestes), les consoles des clouds (EKS, GKE, AKS) et d'OpenShift / Rancher.

## 4. Choisir

```text
Je travaille surtout dans un terminal / en SSH ? ──────────► k9s
Je veux une appli de bureau proche de Lens, libre ? ───────► Freelens
Je veux le même outil sur mon poste ET pour mon équipe
  dans un navigateur, projet CNCF ? ─────────────────────────► Headlamp
Mon entreprise paie déjà Lens et veut le support éditeur ? ─► Lens Desktop
```

Critères à examiner pour tout outil : **licence** et gouvernance, **activité** du dépôt (dernière version, correctifs de sécurité), besoin d'un **compte en ligne**, **télémétrie**, extensibilité, consommation mémoire.

## 5. Installer Freelens

Les versions sont publiées sur la page *Releases* de `freelensapp/freelens` : `.deb`, `.rpm`, AppImage (Linux), `.dmg` (macOS), `.exe`/`.msi` (Windows), ainsi que via Flatpak, Homebrew (`brew install --cask freelens`), Scoop, winget selon les plateformes.

```bash
# Exemple Debian/Ubuntu (remplace X.Y.Z par la dernière version)
sudo apt install ./Freelens-X.Y.Z-linux-amd64.deb
```

Au premier lancement, Freelens détecte les contextes de `~/.kube/config` ; on peut aussi **ajouter un fichier kubeconfig** précis (menu *Add cluster / kubeconfig*).

## 6. Donner un kubeconfig dédié à une interface graphique

Une interface graphique facilite les clics… y compris les mauvais. Pour un usage d'observation, donne-lui un kubeconfig **séparé**, lié à un ServiceAccount en lecture seule, avec un jeton à durée limitée :

```bash
kubectl create serviceaccount gui-lecture -n kube-system
kubectl create clusterrolebinding gui-lecture --clusterrole=view --serviceaccount=kube-system:gui-lecture
TOKEN=$(kubectl create token gui-lecture -n kube-system --duration=24h)
# puis construire un kubeconfig (serveur + CA + jeton), droits 600 — voir le corrigé
```

Un kubeconfig valide contient : un **cluster** (URL du serveur + certificat de l'autorité), un **utilisateur** (jeton ou certificat), un **contexte** qui les associe, et un **contexte courant**. On le contrôle avec :

```bash
kubectl --kubeconfig fichier config view --minify      # structure (secrets masqués)
kubectl --kubeconfig fichier get pods -A                # authentification + droits
kubectl --kubeconfig fichier auth can-i delete pods -A  # doit répondre no
```

---

## Vocabulaire

| Terme | Définition |
|---|---|
| **IDE Kubernetes** | Application de bureau tout-en-un pour explorer et gérer des clusters. |
| **Freemium** | Modèle où une version de base est gratuite et les usages avancés/professionnels payants. |
| **Logiciel propriétaire** | Logiciel dont le code source n'est pas publié sous licence libre. |
| **Fork** | Projet né d'une copie du code d'un autre projet, qui évolue indépendamment. |
| **Lens / OpenLens** | IDE Kubernetes de Mirantis (propriétaire) / sa base libre, aujourd'hui figée. |
| **Freelens** | Fork libre (MIT) et maintenu d'OpenLens. |
| **Electron** | Cadre permettant d'écrire des applications de bureau avec des technologies web. |
| **Télémétrie** | Envoi de données d'usage à l'éditeur d'un logiciel. |
