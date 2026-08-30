---
description: "Audit a SIKA feature, regression or demo blocker before implementation. Identify frontend vs backend cause, rank priority, and propose the minimal safe execution plan."
name: "SIKA Audit"
argument-hint: "Décris la fonctionnalité, le bug ou le parcours à auditer (ex: auth, wallet, transaction, chat, unknown result)."
agent: "SIKA Lead"
---

Analyse le projet SIKA avant toute correction ou validation finale.

Contexte attendu :
- application Flutter
- backend FastAPI déjà déployé
- flux de transaction sécurisé
- contraintes de démonstration / soumission

Ta mission :
1. Identifier l'état réel de la fonctionnalité demandée.
2. Vérifier si le problème est côté Flutter, côté backend, ou côté contrat API.
3. Repérer les blocages critiques pour la démo E2E.
4. Prioriser en P0 / P1 / P2.
5. Proposer un plan minimal, réaliste et sûr.

Focus à vérifier :
- authentification
- wallets
- solde
- historique des transactions
- transferts
- PayMeChap
- SIKA AI / chat
- agent steps
- human confirmation
- biométrie
- UNKNOWN_RESULT / reconciliation

Méthode obligatoire :
1. Explorer l'architecture réelle concernée.
2. Identifier les fichiers et modules responsables.
3. Vérifier les routes API utilisées.
4. Vérifier les appels depuis Flutter.
5. Vérifier si les réponses backend correspondent aux modèles Flutter.
6. Identifier les risques, erreurs ou incompatibilités.
7. Produire un tableau de priorisation propre.

Format de sortie attendu :

## Diagnostic
- description concise du problème ou du parcours

## Tableau de priorisation
| Fonctionnalité | État actuel | Frontend | Backend/API | Bloquant | Priorité | Action recommandée |

## Blocages identifiés
- P0, P1, P2

## Cause probable
- frontend, backend, contrat API, DTO, config, ou autre

## Plan minimal
- étapes courtes et réalistes

## Risques
- éléments à surveiller ou à corriger ensuite

Règles strictes :
- Ne pas commencer un gros refactor.
- Ne pas modifier les fichiers avant d'avoir produit le diagnostic.
- Ne pas masquer UNKNOWN_RESULT comme erreur.
- Respecter la chaîne sécurisée de transaction.
- Priorité absolue : rendre une démo E2E crédible avant la soumission.
- Ne jamais déclarer un test réussi sans preuve d'exécution réelle.
