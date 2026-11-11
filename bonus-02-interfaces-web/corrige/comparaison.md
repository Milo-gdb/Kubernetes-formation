# Headlamp et Kubernetes Dashboard

- Headlamp est maintenu (kubernetes-sigs) ; le Dashboard est archivé : plus aucun correctif de sécurité.
- Headlamp existe aussi en application de bureau et gère plusieurs clusters ; le Dashboard ne tourne que dans un cluster.
- Headlamp s'étend par plugins (Prometheus, Flux…) ; le Dashboard n'est pas extensible.
- Headlamp prend en charge OIDC et les CRD plus complètement.

Raison de ne pas choisir le Dashboard : un composant exposé et non maintenu est un risque de sécurité.
