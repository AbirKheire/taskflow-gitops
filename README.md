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

| Chemin                    | Rôle                                                            |
| ------------------------- | --------------------------------------------------------------- |
| `apps/taskflow/`          | Les manifests surveillés par Argo CD                            |
| `argocd/application.yaml` | Déclare l'application dans Argo CD                              |
| `exemples/bluegreen/`     | Manifests pour le déploiement Blue-Green                        |
| `exemples/canary/`        | Manifests pour le déploiement Canary                            |
| `exemples/robustesse/`    | Canary avec test de charge k6 automatique, modèle de postmortem |
| `exemples/ci/`            | Pipelines de la mini-PSSI (GitHub Actions et GitLab CI)         |
| `policies/`               | Mini-PSSI et règles Rego vérifiées par conftest                 |
| `scripts/install.sh`      | Installation de l'environnement                                 |
| `scripts/argocd-ui.sh`    | Ouvre l'interface d'Argo CD                                     |
| `scripts/observe.sh`      | Montre quelle version répond, et avec quel code HTTP            |
| `scripts/charge.sh`       | Lance à la main le test de charge k6 contre un service          |

## Images disponibles

`ghcr.io/9m7fjfpv9k-cyber/taskflow` en versions `1.0.0`, `1.1.0`, `2.0.0`, `2.1.0` et `2.2.0`.

## Équipe

<!-- Fatoumata Naen Bah  & Abir K -->

4 - Lors du changement de version le déploiement sur Argocd a pris 45 secondes
C'est un toujours un pull, parce que Argocd recupère la version sur la branche main du repo "AbirKheire/taskflow-gitops"
La version de l'image est passée de 1.0.0 sur 2.0.0
Le git revert dans le cas de cette PR fermée permet de revenir à la version 1.0.0

5- Argo CD vérifie la branch main et voit que ce n'est pas les même version et va les annuler tout seul et revenir à 4 réplicas de l’image 2.0.0, parce qu'on l'a fait à la main.

| Question | Ce qu'on a fait                                  | Durée | Mécanisme                                                 | Versions                  |
| -------- | ------------------------------------------------ | ----- | --------------------------------------------------------- | ------------------------- |
| 4        | Changement de version par PR                     | 45 s  | Pull : Argo CD lit `main` de `AbirKheire/taskflow-gitops` | `1.0.0` → `2.0.0`         |
| 5        | `kubectl scale` et `kubectl set image` à la main | —     | Argo CD annule la dérive et revient à Git                 | 4 réplicas, image `2.0.0` |
| 6        | Git revert d'une PR fermée                       | 38 s  | Pull                                                      | `2.0.0` → `1.0.0`         |

## 7. Interface Argo CD

Application Healthy et Synced après synchronisation sur `main`.

![Application taskflow dans Argo CD](docs/argocd-taskflow.jpg)

# TaskFlow - observations du lab

1.0.0 -> Blue-Green -> 1.1.0 -> Canary -> 2.0.0

## A. Blue-Green

Après la PR blue-green, ArgoCD est Healthy et Synced. On a un Rollout à la place du Deployment, et deux services : taskflow et taskflow-preview. 4 pods en 1.0.0.

2 Après la PR en 1.1.0, un deuxième ReplicaSet apparait avec 4 pods. Les 4 anciens restent là, donc on a 8 pods en tout. Le rollout est en Paused, il attend le promote.
Du coup il faut taper cette commande pour le promote: kubectl argo rollouts promote taskflow -n taskflow

observe.sh avant promote :

- taskflow : image dans apps. Observartion on est à la vesion actuelle
- taskflow-preview : image dans apps. Observartion on est à la vesion suivante (attendu)
  /scripts/observe.sh
  40 version=1.0.0 http=200

observe.sh après promote : image dans apps
./scripts/observe.sh taskflow-preview
40 version=1.1.0 http=200

Ce qu'on retient : la nouvelle version tourne à côté sans recevoir de trafic, on peut la tester sur preview, et le promote bascule tout d'un coup.

## B. Canary

PR en `2.0.0` : le Rollout se met en pause à l'étape 1/6, poids 25 %.

- stable 1.1.0 : 3 pods
- canary 2.0.0 : 1 pod
- total : 4 pods, pas 8 comme en blue-green

observe.sh :
./scripts/observe.sh
33 version=1.1.0 http=200
7 version=2.0.0 http=200

```
33 version=1.1.0 http=200
7 version=2.0.0 http=200
7 requêtes sur 40 vont sur la `2.0.0`, un peu moins que 25 %. Sur 40 requêtes c'est normal : la répartition suit le nombre de pods (1 sur 4). Que des 200, pas d'erreur.
```

PR en `2.1.0`. Le déploiement avance par pauses, puis un promote amène le poids à 100 %.

reponse 4: ./scripts/observe.sh taskflow
32 version=2.0.0 http=200
5 version=2.1.0 http=200
3 version=aucune http=500
Promote jusqu'à 100 % : image dans apps

PR en 2.1.0, codes HTTP : image dans apps
le déploiement se fait progressivement parce on fait des pauses de 60s et après il faut taper la commande pour faire le full promote

Abort et après : image dans apps
Après le "Abort" on a l'état de Argocd en Degraded parce que on a arbort à la main via la commande "kubectl argo rollouts abort taskflow -n taskflow". Sachant Argocd pull les informations de git de la branche main et la version sur git reste sur la 2.1.0 par la PR qu'on avait ouverte, d'où le degraded dans Argocd

## Blue-Green ou Canary pour TaskFlow

On choisit Canary.

| Critère                            | Blue-Green                                                                                 | Canary                                                                     |
| ---------------------------------- | ------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------- |
| Risque                             | Tout le monde bascule d'un coup. Un mauvais test sur preview touche tous les utilisateurs. | Seule une partie des utilisateurs voit la nouvelle version. On peut abort. |
| Pods pendant le déploiement        | 8                                                                                          | 4                                                                          |
| Durée                              | Le promote bascule tout de suite                                                           | Plus long : les deux versions tournent ensemble                            |
| Versions incompatibles entre elles | Plus adapté                                                                                | Les deux versions répondent à de vrais utilisateurs en même temps          |

Coût : blue-green demande le double de pods pendant le déploiement (8 au lieu de 4). Canary reste à 4.

Le défaut du canary : c'est plus long, et les deux versions tournent en même temps pour de vrais utilisateurs. Si elles ne sont pas compatibles entre elles, blue-green est plus adapté.

LAB MATIN J3

2- Note erreur et p95
| Seuil | Exigence | Mesure | OK |
| --- | --- | --- | --- |
| `http_req_duration` p(95) | < 250 ms | 7,82 ms | oui |
| `http_req_failed` | < 2 % | 0,00 % (0 / 730) | oui |
| checks `statut 200` | — | 100 % (730 / 730) | oui |

THRESHOLDS
| Métrique | Valeur |
| --- | --- |
| Durée | 30 s |
| Requêtes | 730 (24,3 /s) |
| p(95) durée HTTP | 7,82 ms |
| Moyenne durée HTTP | 4,32 ms |
| Erreurs HTTP | 0,00 % |
| VU | 5 |

    http_req_duration
    ✓ 'p(95)<250' p(95)=7.82ms

| CRD                                    | Portée     |
| -------------------------------------- | ---------- |
| `analysisruns.argoproj.io`             | Namespaced |
| `analysistemplates.argoproj.io`        | Namespaced |
| `clusteranalysistemplates.argoproj.io` | Cluster    |
| `rollouts.argoproj.io`                 | Namespaced |

`kubectl -n taskflow get rollout,deploy` : un Rollout, aucun Deployment.

| Ressource                      | Détail                                       |
| ------------------------------ | -------------------------------------------- |
| `rollout.argoproj.io/taskflow` | desired 4, current 4, up-to-date 4, âge 20 h |
| `configmap/kube-root-ca.crt`   | 1 donnée, âge 23 h                           |
| `service/taskflow`             | ClusterIP `10.96.137.122`, port 80, âge 20 h |

Partie 2 :
Premier test (30 s) : 638 requêtes, 2,66 % d'erreurs (17 échecs) et un p95 à 305 ms. Les deux seuils sont dépassés, le test échoue.
Deuxième test de (60 s) : 1456 requêtes, 0 % d'erreur et un p95 à 11 ms. Les deux seuils sont respectés, le test réussit.

Le service est donc resté stable et rapide pendant une minute entière : aucune requête en échec, et la plus lente a pris 38 ms contre 320 ms lors du premier test. Le débit est aussi meilleur, environ 24 requêtes par seconde contre 21, parce qu'il n'y a plus de requêtes lentes qui retardent les utilisateurs virtuels. Le test de 60 s confirme surtout que ce bon comportement tient dans le temps, avec deux fois plus de requêtes pour l'appuyer.

Partie 4 (A) Image 1 : 01-aucun-deployment.png
Commande : kubectl -n taskflow get deployment
Légende : Figure 1 – Aucun Deployment dans le namespace taskflow : la commande ne renvoie aucune ressource, ce qui confirme que le Deployment a bien été remplacé.

Image 2 : 02-rollout-taskflow.png
Commande : kubectl -n taskflow get rollout
Légende : Figure 2 – Le Rollout taskflow gère désormais l'application : 4 réplicas souhaités, 4 disponibles, dont 3 à jour.

Image 3 : 03-crd-argo.png
Commande : kubectl get crd | grep argoproj.io
Légende : Figure 3 – CRD Argo installées dans le cluster : celles d'Argo Rollouts (analysisruns, analysistemplates, clusteranalysistemplates, experiments) et celles d'Argo CD (applications, applicationsets, appprojects).

Image 4 : 04-ressources-analyse.png
Commande : kubectl -n taskflow get analysistemplate,configmap,svc
Légende : Figure 4 – Ressources créées par la PR feat/analyse-auto : l'AnalysisTemplate robustesse-k6, le ConfigMap k6-robustesse et le service taskflow-canary, aux côtés du service taskflow existant.



# Postmortem — La 2.1.0 est arrivée en production alors que l'analyse devait la bloquer


| Champ | Valeur |
| --- | --- |
| Date et heure | Jeudi 8 octobre 2026, 11h40 |
| Version en cause | `taskflow:2.1.0` |
| PR à l'origine | PR #18 `feat/image-2.1.0` |
| Durée d'exposition | De 11h40 à environ 13h51, un peu plus de 2 heures |
| Part du trafic touché | 25 % puis 100 % dès 11h43, 75 % pendant le revert |
| Détecté par | Rien d'automatique : probes vertes et test k6 réussi |
| Résolu par | `git revert` (PR #21). Pas d'abort automatique. |

## Chronologie

Heures de Paris. Celles avec « ≈ » sont calculées à partir de l'âge des pods.

| Heure | Événement |
| --- | --- |
| Veille, 16h05 | Un canary `2.1.0` reste en pause à 25 % toute la nuit. |
| 10h57 | Test de charge à la main : 2,66 % d'erreurs, p95 à 305 ms. Les deux suivants sont bons. |
| 11h13 | PR #16 : image `2.0.0` + analyse k6. 4 pods en `2.0.0` vers 11h18. |
| 11h38 | PR #18 : image `2.1.0`. |
| 11h40 | Canary `2.1.0` à 25 %, l'analyse démarre. |
| ≈ 11h41 | Analyse `Successful`. |
| ≈ 11h43 | La `2.1.0` est à 100 %, `Healthy`. |
| 12h06 | Revert (PR #21). Il repasse par le canary et l'analyse. |
| 13h40 | Revert bloqué à 25 % : l'analyse tourne toujours, application `Degraded`. |
| 13h47 | PR #22 : on enlève l'analyse pour débloquer. |
| ≈ 13h51 | 4 pods en `2.0.0`. Fin de l'incident. |
| ≈ 14h18 | Premier essai `2.2.0` : analyse en échec (faute dans notre script k6), abort automatique. |
| ≈ 14h47 | Script corrigé (PR #25) puis `retry` : analyse réussie, `2.2.0` à 100 %. |

![Rollout Healthy en 2.1.0](../preuve1-résultat-rollout.png)

*Figure 1 – La `2.1.0` est stable à 100 %.*

![Argo CD pendant le revert](../argocd_preuve.png)

*Figure 2 – À 13h40, le revert est bloqué : Rollout Degraded, analyse non terminée.*

## Composant défaillant et cause racine

**Quel composant a échoué ?** L'application en `2.1.0`. Elle répond sur `/health`, mais certaines requêtes échouent ou sont lentes. Preuve, `./scripts/charge.sh http://taskflow` à 10h57 avec 1 pod sur 4 en `2.1.0` :

```
http_req_duration   ✗ 'p(95)<250'   p(95)=305.15ms
http_req_failed     ✗ 'rate<0.02'   rate=2.66%  (17 out of 638)
```

La veille, `observe.sh` montrait aussi des erreurs 500 dès que la `2.1.0` recevait du trafic. Le problème n'apparaît pas à chaque fois : les deux tests suivants étaient bons.

**Pourquoi les probes ne l'ont-elles pas vu ?** Elles appellent seulement `/health`, qui répond toujours, même quand `/tasks` renvoie des erreurs.

![Définition des probes](../preuve4.png)

*Figure 3 – Les deux probes n'appellent que `/health`.*

**Pourquoi l'analyse ne l'a-t-elle pas vu ?** Elle fait un seul test k6 d'une minute, au palier de 25 %. Comme le problème va et vient, ce test est tombé au bon moment.

![Verdict de l'analyse](../preuve2.1.png)

*Figure 4 – L'AnalysisRun de la `2.1.0` est Successful.*

**Cause racine :** la `2.1.0` a un bug qui n'apparaît pas tout le temps, et nos contrôles ne pouvaient pas l'attraper. Les probes ne regardent que `/health` et l'analyse ne fait qu'un seul test court. On ne connaît pas l'origine du bug, ce dépôt ne contient pas le code de l'application.

## Ce qui a bien fonctionné

- Tout est passé par des PR, on retrouve tout dans Git.
- Argo CD a appliqué chaque changement tout seul.
- L'abort automatique fonctionne : on l'a vu à 14h18 sur le premier essai de la `2.2.0`.
- La `2.2.0` est en production, avec une analyse réussie.

![Argo CD Healthy en 2.2.0](../argocd-2.2.0-healthy.png)

*Figure 5 – `2.2.0` Healthy. L'AnalysisRun `9-1` est en échec (script k6 cassé), le `9-1.1` est réussi.*

## Actions correctives

| Action | Responsable | Échéance |
| --- | --- | --- |
| Faire plusieurs tests k6, et tester à chaque palier | Binôme | Prochain déploiement |
| Faire tester `/tasks` par la readiness probe | Binôme | Prochain déploiement |
| Ne pas laisser un canary en pause toute la nuit | Binôme | Dès maintenant |
| Ne pas enlever l'analyse pour débloquer un revert | Binôme | Dès maintenant |
| Vérifier les YAML et le script k6 avant de fusionner | Binôme | Dès maintenant |

