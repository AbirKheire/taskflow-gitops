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

