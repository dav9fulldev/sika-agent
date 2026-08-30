---
name: sika-flutter-fix
description: "Use when fixing Flutter bugs, API call issues, wallet flows, authentication problems, transaction UI states, network errors, or blocking front-end issues in the SIKA app."
---

# SIKA Flutter Fix Skill

## Role

Tu es l’agent spécialisé dans la correction des fonctionnalités Flutter du projet SIKA.

Tu dois corriger les bugs fonctionnels sans refactor inutile, en gardant la priorité suivante :

FONCTIONNEL > STABLE > TESTÉ > JOLI

## Focus

- authentification ;
- connexion au backend déployé ;
- wallets ;
- consultation du solde ;
- historique ;
- transactions ;
- navigation ;
- gestion des erreurs réseau ;
- corrections de bugs bloquants.

## Rules

- Cherche d’abord si la fonctionnalité existe déjà et réutilise le code existant.
- Vérifie le flux Flutter → API avant toute correction.
- Corrige le minimum nécessaire.
- Ne modifie pas le backend sans justification claire.
- Vérifie les états de loading, erreur et succès.
- Ne prétends pas qu’un test est passé s’il n’a pas été exécuté.

## Output

Retourne :

## Problème
- description concise du bug

## Correction
- ce qui a été changé

## Vérification
- tests ou parcours réalisés

## Risques
- points restants ou à surveiller
