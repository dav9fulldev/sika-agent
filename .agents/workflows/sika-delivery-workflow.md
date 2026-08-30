# SIKA DELIVERY WORKFLOW

## Objectif

Régir le flux de travail de correction et de validation sur SIKA en gardant une logique minimale, sécurisée et orientée vers la démonstration du parcours principal.

---

## Étape 1 — Diagnostic initial

Démarrer par le SIKA Lead Agent.

Il doit :

- comprendre le bug ou la demande ;
- lire les fichiers clés ;
- identifier le flux concerné ;
- vérifier si la fonctionnalité existe déjà ;
- décider si le problème vient du Flutter, du contrat API ou du backend ;
- proposer une correction minimale.

Si le sujet touche le business logic ou la sécurité financière, le Lead doit bloquer tout refactor inutile.

---

## Étape 2 — Correction fonctionnelle

Si la tâche concerne l'application Flutter, déléguer au SIKA Flutter Functional Agent.

Il doit prioriser :

- authentification ;
- backend connectivity ;
- wallets ;
- solde ;
- historique ;
- transactions ;
- navigation ;
- gestion réseau ;
- bugs bloquants.

---

## Étape 3 — Vérification du flux transactionnel

Si la tâche concerne :

- préparation de transfert ;
- confirmation ;
- biométrie ;
- /agent/confirm ;
- JWT ;
- orchestration ;
- UNKNOWN_RESULT ;
- sécurité financière ;

alors déléguer au SIKA Integration & Transaction Agent.

Ce agent doit valider la chaîne complète sans contourner la sécurité backend.

---

## Étape 4 — Validation technique

Après la correction :

- vérifier les imports ;
- vérifier les erreurs de compilation ;
- lancer les commandes pertinentes ;
- exécuter flutter analyze ;
- exécuter flutter test si le test est pertinent ;
- tester manuellement le parcours concerné.

Ne jamais inventer un résultat de test.

---

## Étape 5 — Résumé de livraison

Renvoyer un résumé structuré :

## Problème identifié
## Fichiers concernés
## Correction réalisée
## Vérification
## Risques restants
## Recommandation suivante

Le but est de garder le projet opérationnel, sûr et démontrable.

---

## Règle finale

Toujours privilégier :

FONCTIONNEL > STABLE > TESTÉ > JOLI

et ne jamais contourner la chaîne sécurisée du flux financier SIKA.
