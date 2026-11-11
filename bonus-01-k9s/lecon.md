# Bonus 01 — k9s : piloter son cluster au clavier

> **Objectifs** : installer k9s, naviguer entre les ressources au clavier, lire des logs, ouvrir un shell, faire un port-forward, filtrer/trier, consulter les events, et diagnostiquer une panne sans taper une seule commande `kubectl`.
>
> **Durée estimée** : 1 h 30 — **Prérequis** : chapitres 03 à 08.

---

## 1. Pourquoi k9s ?

`kubectl` est indispensable mais verbeux : pour suivre un incident, on enchaîne `get pods`, `describe`, `logs --previous`, `get events --sort-by`… **k9s** est une **interface en mode texte** (TUI) qui affiche les ressources en temps réel et donne accès à toutes ces actions par des raccourcis clavier. C'est un logiciel libre (licence Apache-2.0, projet `derailed/k9s`), qui fonctionne dans n'importe quel terminal, y compris via SSH.

k9s n'a **rien à installer dans le cluster** : comme `kubectl`, il lit ton **kubeconfig** et agit avec **tes droits RBAC**. Ce que tu ne peux pas faire avec kubectl, tu ne peux pas le faire avec k9s.

## 2. Installation

=== "Binaire (toutes distributions)"

    ```bash
    VERSION=v0.51.0   # dernière version : https://github.com/derailed/k9s/releases
    curl -sSLO https://github.com/derailed/k9s/releases/download/${VERSION}/k9s_Linux_amd64.tar.gz
    tar xzf k9s_Linux_amd64.tar.gz k9s
    sudo install k9s /usr/local/bin/
    k9s version
    ```

=== "Gestionnaires de paquets"

    ```bash
    brew install derailed/k9s/k9s     # macOS / Linuxbrew
    sudo snap install k9s --devmode    # Ubuntu (snap)
    winget install k9s                 # Windows
    ```

k9s utilise la variable `KUBECONFIG` ou, à défaut, `~/.kube/config` (chapitre 02). Vérifie d'abord que `kubectl get nodes` fonctionne : si kubectl échoue, k9s échouera aussi.

```bash
k9s                       # contexte et namespace courants
k9s -n task-manager       # démarrer dans un namespace
k9s -c deploy             # démarrer directement sur la vue Deployments
k9s --readonly            # interdire toute modification (idéal pour observer la production)
k9s info                  # emplacement des fichiers de configuration
```

## 3. Se repérer dans l'écran

```text
┌ Context: default  Cluster: default  User: default   K9s Rev: v0.51.0   CPU: 3%  MEM: 41% ┐
│  <0> all   <1> task-manager   <2> default          <ctrl-d> Delete   <l> Logs   <s> Shell  │ ← raccourcis disponibles
├──────────────────────────── Pods(task-manager)[5] ──────────────────────────────────────────┤
│ NAME↑                       READY  STATUS    RESTARTS  CPU  MEM  IP           NODE       AGE │
│ api-7d9c...                 1/1    Running   0         2    11   10.42.0.31   devin-box  2h  │
│ postgres-0                  0/1    CrashLoopBackOff 6  0    0    10.42.0.40   devin-box  9m  │ ← ligne rouge = problème
└──────────────────────────────────────────────────────────────────────────────────────────────┘
  <pod>                                                                         ← fil d'Ariane
```

- L'**en-tête** rappelle le contexte, le cluster et les raccourcis valables **dans la vue actuelle** : ils changent d'une vue à l'autre.
- Les couleurs signalent l'état : les lignes en erreur ressortent immédiatement.
- `?` affiche l'aide complète de la vue ; `Échap` revient en arrière ; `:q` ou `Ctrl-c` quitte.

## 4. Naviguer : le mode commande `:`

On tape `:` suivi du nom (ou de l'abréviation) d'une ressource, puis `Entrée` — exactement les noms courts de kubectl :

| Commande | Vue |
|---|---|
| `:pods` / `:po` | Pods |
| `:deploy` / `:dp` | Deployments |
| `:svc` | Services |
| `:ing` | Ingress |
| `:cm`, `:secrets` | ConfigMaps, Secrets |
| `:pvc`, `:pv` | volumes |
| `:sts`, `:ds`, `:jobs`, `:cj` | StatefulSets, DaemonSets, Jobs, CronJobs |
| `:events` / `:ev` | events |
| `:ns` | namespaces (Entrée sur un namespace = s'y placer) |
| `:ctx` | contextes du kubeconfig (changer de cluster) |
| `:node` / `:no` | nœuds |
| `:xray deploy` | arbre Deployment → ReplicaSet → Pod → conteneur |
| `:pulses` | tableau de bord général |

`Tab` complète le nom de la ressource. Dans une vue, `Entrée` « descend » : Deployment → ses Pods → ses conteneurs. Les chiffres `0`, `1`, `2`… basculent entre « tous les namespaces » et les namespaces récemment utilisés.

## 5. Agir sur une ressource

Sélectionne une ligne avec les flèches (ou `j`/`k`), puis :

| Touche | Action | Équivalent kubectl |
|---|---|---|
| `d` | describe | `kubectl describe` |
| `y` | afficher le YAML | `kubectl get -o yaml` |
| `e` | éditer dans `$EDITOR` | `kubectl edit` |
| `l` | logs du conteneur | `kubectl logs -f` |
| `p` | logs du conteneur **précédent** (celui qui a planté) | `kubectl logs --previous` |
| `s` | shell dans le conteneur | `kubectl exec -it -- sh` |
| `Shift-f` | port-forward | `kubectl port-forward` |
| `Ctrl-d` | supprimer (avec confirmation) | `kubectl delete` |
| `Ctrl-k` | supprimer sans confirmation (*kill*) | `kubectl delete --now` |
| `s` (sur un Deployment) | changer le nombre de réplicas (*scale*) | `kubectl scale` |
| `r` (sur un Deployment) | redémarrage progressif | `kubectl rollout restart` |

Dans la vue des **logs** : `0` à `5` choisissent la période affichée (tout, 1 min, 5 min…), `w` active le retour à la ligne, `s` le défilement automatique, `t` les horodatages, `/` filtre, `Ctrl-s` enregistre dans un fichier.

Les port-forwards actifs se gèrent dans la vue `:pf`.

!!! warning "Les raccourcis évoluent"
    k9s change vite d'une version à l'autre. En cas de doute, la référence est toujours l'en-tête et l'aide `?` de **ta** version.

## 6. Filtrer et trier

- `/` puis un texte : filtre les lignes (expression régulière). `/!texte` inverse le filtre, `/-l app=api` filtre par **label**, `/-f texte` fait une recherche approximative.
- `Échap` efface le filtre.
- **Tri** : les colonnes se trient avec `Shift` + une lettre — notamment `Shift-n` (nom), `Shift-a` (âge), `Shift-s` (statut), `Shift-c` (CPU), `Shift-m` (mémoire, chiffres fournis par metrics-server). Une seconde pression inverse l'ordre ; la colonne triée est marquée d'une flèche.

Exemple : dans `:pods` en vue « tous les namespaces » (`0`), `Shift-m` montre immédiatement les Pods les plus gourmands en mémoire.

## 7. Les events

La vue `:events` liste les events du namespace (planification, téléchargement d'image, sonde en échec, OOMKilled, `BackOff`…). Trie-les par âge (`Shift-a`) pour lire l'histoire d'un incident dans l'ordre. Le `describe` (`d`) d'un Pod affiche aussi, en bas, les events qui le concernent.

## 8. Méthode de diagnostic avec k9s

```text
:pods (0 = tous les namespaces)   → repérer la ligne rouge, la colonne RESTARTS
   d (describe)                    → State / Last State / Reason / Exit Code, events en bas
   p (logs précédents)             → message d'erreur du conteneur mort
   l (logs actuels)                → état du conteneur relancé
:events                            → chronologie
:deploy → e (edit)                 → corriger, puis observer le redémarrage en direct
```

| Statut | Piste |
|---|---|
| `CrashLoopBackOff` | le processus s'arrête : lire les **logs précédents** (`p`) |
| `ImagePullBackOff` / `ErrImagePull` | nom/tag d'image ou accès au registre : `d` |
| `CreateContainerConfigError` | Secret/ConfigMap ou clé référencé introuvable : `d` |
| `Pending` | ressources insuffisantes, PVC non liée, quota : `d` + `:events` |
| `Running` mais `0/1` | sonde de readiness en échec : `d` |
| `OOMKilled` (Last State) | limite mémoire trop basse : `:deploy` → `e` |

## 9. Personnaliser (aperçu)

Les fichiers de `k9s info` permettent d'ajouter des **alias** (`aliases.yaml`), des **raccourcis personnalisés** vers des commandes (`plugins.yaml`), des **thèmes** (*skins*) et de choisir les colonnes affichées (`views.yaml`).

---

## Vocabulaire

| Terme | Définition |
|---|---|
| **TUI** | *Text User Interface* : interface interactive dans un terminal. |
| **Mode commande (`:`)** | Saisie du nom d'une ressource pour changer de vue. |
| **Vue** | Liste d'un type de ressource, rafraîchie en continu. |
| **Contexte** | Couple cluster + utilisateur (+ namespace) du kubeconfig, sélectionnable par `:ctx`. |
| **Logs précédents** | Journal du conteneur qui a précédé le redémarrage en cours (`p`). |
| **Port-forward** | Tunnel local vers un Pod ou un Service (`Shift-f`, vue `:pf`). |
| **Xray** | Vue arborescente des ressources et de leurs dépendances. |
| **Mode lecture seule** | Option `--readonly` qui désactive toute action modifiant le cluster. |
