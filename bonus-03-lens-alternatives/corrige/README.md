# Corrigé TD bonus 03

## Exercice 1

Les dates changent : vérifie toujours les pages *Releases*. Exemple de réponse : [`choix.md`](choix.md). Points attendus : Lens est **propriétaire/freemium** avec compte obligatoire, **OpenLens est figé** depuis la fermeture du code de Lens, **Freelens** (MIT) en est le fork maintenu, **Headlamp** (Apache-2.0) est le projet de la communauté Kubernetes.

## Exercice 2 — [`creer-kubeconfig-gui.sh`](creer-kubeconfig-gui.sh)

```bash
./creer-kubeconfig-gui.sh
K=~/formation-k8s/bonus03/kubeconfig-gui
ls -l $K                                                          # -rw-------
kubectl --kubeconfig $K config current-context                    # formation-lecture
kubectl --kubeconfig $K get pods -n task-manager                  # OK
kubectl --kubeconfig $K auth can-i delete pods -n task-manager    # no
kubectl --kubeconfig $K get secrets -n task-manager               # Forbidden
```

Le jeton expire au bout de 24 h : il suffit de relancer le script. Pour révoquer immédiatement l'accès, supprime le ServiceAccount ou le ClusterRoleBinding.

## Exercice 3

Le redimensionnement échoue avec un message `forbidden` (`cannot patch resource "deployments/scale"`) : l'interface applique les droits du kubeconfig. Freelens offre la vue la plus « IDE » (onglets, terminal, métriques), Headlamp la même chose dans le navigateur, k9s est le plus rapide au clavier.
