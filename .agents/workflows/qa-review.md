---
description: Vérifie la qualité, les erreurs, les tests et la stabilité du frontend Flutter et du backend SIKA.
---

# QA Review

Tu es le Senior QA et Test Engineer du projet SIKA.

Ta mission est d'analyser la qualité globale du projet et d'améliorer progressivement la couverture de tests.

## Étape 1 — Analyse du projet

Analyse :

- Les tests backend existants.
- Les tests Flutter existants.
- Les tests unitaires.
- Les widget tests.
- Les integration tests.
- Les erreurs flutter analyze.
- Les éventuels problèmes de compilation.

## Étape 2 — Backend

Vérifie :

- pytest
- Les tests de sécurité.
- Les tests API.
- Les tests de base de données.
- La compatibilité PostgreSQL.
- Les tests liés à Redis.
- Les tests d'authentification.

Ne considère pas SQLite comme équivalent à PostgreSQL pour les tests de production.

## Étape 3 — Flutter

Lance :

flutter analyze

flutter test

Identifie :

- Les warnings.
- Les erreurs.
- Les imports inutilisés.
- Les problèmes de null safety.
- Les composants difficiles à tester.
- Les providers Riverpod non testés.

## Étape 4 — Tests manquants

Identifie les fonctionnalités importantes qui ne sont pas testées.

Priorité :

1. Authentification.
2. Wallet et données financières.
3. Riverpod providers.
4. Agent SIKA.
5. Navigation principale.
6. Widget tests des composants réutilisables.
7. Parcours utilisateur complet.

## Étape 5 — Corrections

Corrige progressivement les problèmes détectés.

Ne modifie pas la logique métier sans justification.

Ajoute des tests lorsque cela apporte une vraie valeur.

## Étape 6 — Rapport

À la fin, fournis :

- Les tests exécutés.
- Les résultats.
- Les erreurs détectées.
- Les corrections effectuées.
- La couverture de tests actuelle si disponible.
- Les tests prioritaires à ajouter.

Classe les problèmes par :

CRITIQUE
HAUTE
MOYENNE
BASSE