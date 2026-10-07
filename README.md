# taskflow-gitops — dépôt GitOps du cours CI/CD M2

Ce dépôt décrit **l'état voulu** de l'application TaskFlow dans Kubernetes.
Argo CD le surveille et aligne le cluster dessus : pour changer la production,
on ne tape pas de commande, on fait une **Pull Request**.

## Installation (à faire chez vous, avant le cours)

Prérequis : Docker Desktop démarré, 8 Go de RAM, 10 Go de disque libre.
Sous Windows : WSL2 (Ubuntu) + intégration WSL de Docker Desktop, et toutes les commandes dans WSL.

```bash
git clone https://github.com/9m7fjfpv9k-cyber/taskflow-gitops.git
cd taskflow-gitops
./scripts/install.sh
```

Le script crée un cluster local `kind`, installe Argo CD et Argo Rollouts,
puis télécharge les images des labs. Comptez 5 à 15 minutes.
Il peut être relancé sans risque.

## Structure

| Chemin                    | Rôle                                                 |
| ------------------------- | ---------------------------------------------------- |
| `apps/taskflow/`          | Les manifests surveillés par Argo CD                 |
| `argocd/application.yaml` | Déclare l'application dans Argo CD                   |
| `exemples/bluegreen/`     | Manifests pour le déploiement Blue-Green             |
| `exemples/canary/`        | Manifests pour le déploiement Canary                 |
| `scripts/install.sh`      | Installation de l'environnement                      |
| `scripts/argocd-ui.sh`    | Ouvre l'interface d'Argo CD                          |
| `scripts/observe.sh`      | Montre quelle version répond, et avec quel code HTTP |

## Images disponibles

`ghcr.io/9m7fjfpv9k-cyber/taskflow` en versions `1.0.0`, `1.1.0`, `2.0.0` et `2.1.0`.

## Équipe

<!-- Fatoumata Naen Bah  & Abir K -->

4 - Lors du changement de version le déploiement sur Argocd a pris 45 secondes
C'est un toujours un pull, parce que Argocd recupère la version sur la branche main du repo "AbirKheire/taskflow-gitops"
La version de l'image est passée de 1.0.0 sur 2.0.0
Le git revert dans le cas de cette PR fermée permet de revenir à la version 1.0.0

5- Argo CD vérifie la branch main et voit que ce n'est pas les même version et va les annuler tout seul et revenir à 4 réplicas de l’image 2.0.0, parce qu'on l'a fait à la main.

6- Pour le revert le déploiement à fait 38 secondes, c'était un pull. Du coup la correction était: version 2.0.0 à 1.0.0 et le deploiement revient a la version 1.0.0

7-
Après le merge de la PR #2, l'application est **Healthy** et **Synced** sur `main`. Argo CD a déployé tout seul (auto sync) le nouveau ReplicaSet
(rev 2) fait tourner les 4 pods, l'ancien (rev 1) est vide.

![Application taskflow dans Argo CD](docs/argocd-taskflow.jpg)
