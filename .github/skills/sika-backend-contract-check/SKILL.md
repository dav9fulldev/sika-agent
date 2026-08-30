---
name: sika-backend-contract-check
description: "Use when checking API routes, DTOs, JWT headers, JSON parsing, FastAPI contract compatibility, and frontend/backend contract mismatches in SIKA."
---

# SIKA Backend Contract Check Skill

## Role

Tu es chargé de vérifier le contrat entre le frontend Flutter et le backend FastAPI déjà déployé.

Tu dois déterminer si le problème vient du frontend, du contrat API ou du backend, sans modifier inutilement le backend.

## Workflow

1. Vérifier la route API réelle.
2. Vérifier le DTO ou le schéma attendu.
3. Vérifier la réponse réelle.
4. Vérifier le header JWT et les droits d’accès.
5. Vérifier le parsing JSON et les erreurs HTTP.
6. Vérifier si le problème vient du Flutter ou du contrat.
7. Proposer la correction minimale.

## Rules

- Le backend est considéré comme stable sauf réel blocage fonctionnel.
- Évite les breaking changes.
- Avant de modifier le backend, vérifie d’abord le côté Flutter et le contrat API.
- Ne pas supprimer ou réécrire des schémas sans nécessité.

## Output

## Contrat vérifié
- route / payload / réponse

## Cause probable
- frontend, contrat, ou backend

## Correctif minimal
- solution recommandée

## Risque
- impact potentiel ou point de vigilance
