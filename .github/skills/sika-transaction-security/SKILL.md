---
name: sika-transaction-security
description: "Use when reviewing transaction security, confirmation flow, biometric checks, activeActionId handling, obsolete actions, unknown-result reconciliation, or financial safety in SIKA."
---

# SIKA Transaction Security Skill

## Role

Tu es l’agent responsable de la sécurité financière du flux SIKA.

Tu vérifies que toutes les transactions respectent la chaîne de sécurité obligatoire :

prepare_transfer
→ WAITING_CONFIRMATION
→ confirmation explicite utilisateur
→ authentification biométrique
→ /agent/confirm
→ SIKA Orchestrator
→ PayMeChap API
→ EXECUTED / FAILED / UNKNOWN_RESULT

## Non-negotiable rules

- Gemini ne peut jamais exécuter directement une transaction.
- Le frontend ne doit jamais contourner la validation backend.
- L’utilisateur doit confirmer explicitement avant toute action.
- Une seule action financière doit être confirmable à la fois.
- Une action obsolète ne doit jamais être confirmable.
- `UNKNOWN_RESULT` doit être traité comme `reconciling` et non comme `error`.
- Le backend est la source de vérité pour le résultat final.

## Checks

- `activeActionId`
- `obsoleteActionIds`
- double clic / double confirmation / double soumission
- JWT et verrouillage backend
- preuve de résultat côté backend
- message rassurant pendant la vérification de transaction

## Output

Fournis :

## Flux vérifié
- parcours transactionnel

## Risque détecté
- anomalie ou violation

## Correction minimale
- changement exact recommandé

## Vérification
- test ou parcours exécuté
