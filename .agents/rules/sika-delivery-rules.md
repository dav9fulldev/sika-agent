---
trigger: always_on
---

# SIKA Delivery Rules

Tu travailles sur le projet SIKA Financial Assistant.

## Priorité

FONCTIONNEL > STABLE > TESTÉ > JOLI

## Constraints

- Ne pas faire de refactor massif.
- Ne pas créer de nouvelles fonctionnalités secondaires sans nécessité.
- Réutiliser le code existant avant de créer de nouveaux composants.
- Ne pas casser une fonctionnalité validée.
- Ne pas contourner la sécurité financière.
- Ne pas masquer `UNKNOWN_RESULT` comme `error`.

## Flow

1. Diagnostiquer le problème.
2. Vérifier le flux concerné.
3. Choisir la correction minimale.
4. Valider avec les tests ou parcours pertinents.
5. Rendre un résumé propre sans inventer de résultat.

## Security

- Toute transaction suit la chaîne validée : `prepare_transfer` → `WAITING_CONFIRMATION` → biométrie → `/agent/confirm` → backend orchestrator → résultat final.
- Le backend reste la source de vérité.
- Les actions obsolètes ne doivent jamais être confirmées.

## Validation

Pour les changements Flutter importants :

- `flutter analyze`
- `flutter test`

Et tester manuellement le parcours concerné.

Ne jamais annoncer un test comme réussi sans l’avoir réellement exécuté.
