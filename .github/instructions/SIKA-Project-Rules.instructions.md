---
description: "Use when working on the SIKA financial assistant, Flutter frontend, backend API, transaction flows, Gemini orchestration, security validation, wallet logic, or project delivery tasks. Covers priority order, financial safety rules, state handling, reusable code, and minimal-change workflows."
name: "SIKA Project Rules"
applyTo: "**"
---

# SIKA FINANCIAL ASSISTANT — GLOBAL PROJECT RULES

## PROJECT CONTEXT

Tu travailles sur le projet SIKA Financial Assistant.

SIKA est un assistant financier intelligent basé sur :

Flutter
↓
FastAPI
↓
SIKA Orchestrator
↓
Gemini
↓
Function Calling
↓
ReAct Loop
↓
Tool Registry
↓
Human-in-the-Loop
↓
Biometric Authentication
↓
PayMeChap API

Le backend est déjà déployé.

La priorité actuelle est de finaliser les fonctionnalités principales avant la soumission du projet.

---

# PRIORITÉ ABSOLUE

Ne pas perdre du temps sur :

- gros refactor ;
- architecture inutilement complexe ;
- nouvelles fonctionnalités secondaires ;
- amélioration esthétique non essentielle ;
- duplication de composants existants.

La priorité est :

1. Application Flutter fonctionnelle.
2. Communication Flutter ↔ Backend déployé.
3. Authentification fonctionnelle.
4. Wallets et données financières.
5. Consultation du solde.
6. Historique des transactions.
7. Chat SIKA fonctionnel.
8. Préparation d'une transaction.
9. Confirmation sécurisée.
10. Gestion du résultat de transaction.
11. Correction des bugs bloquants.
12. Validation avant soumission.

---

# BACKEND

Le backend doit être considéré comme stable.

Ne pas modifier le backend sauf si une incompatibilité réelle du contrat Frontend/Backend empêche une fonctionnalité importante de fonctionner.

Avant toute modification backend :

1. Vérifier la route API.
2. Vérifier le DTO.
3. Vérifier la réponse réelle.
4. Vérifier si le problème vient plutôt du Flutter.
5. Proposer la correction minimale.

Éviter les breaking changes.

---

# SÉCURITÉ FINANCIÈRE

Gemini ne peut jamais exécuter directement une transaction.

Toute transaction doit obligatoirement suivre :

prepare_transfer
→ WAITING_CONFIRMATION
→ confirmation explicite utilisateur
→ authentification biométrique
→ /agent/confirm
→ SIKA Orchestrator
→ PayMeChap API
→ EXECUTED / FAILED / UNKNOWN_RESULT

Le frontend ne doit jamais contourner :

- WAITING_CONFIRMATION
- biométrie
- /agent/confirm
- JWT
- verrouillage backend
- SIKA Orchestrator

Le frontend n'est jamais la source de vérité pour déterminer qu'une transaction est exécutée.

Seul le backend décide du résultat final.

---

# SIKA AI

SIKA utilise Gemini avec :

- Function Calling
- boucle ReAct
- mémoire conversationnelle
- Tool Registry

Ne jamais réintroduire un système basé sur :

if "envoie" in message

Ne jamais exposer :

- chaîne de pensée ;
- raisonnement interne ;
- prompts système ;
- détails internes du modèle.

Les agent_steps affichés au frontend doivent uniquement représenter des événements observables et sûrs.

Exemples autorisés :

- Compréhension de votre demande
- Analyse de votre situation financière
- Recherche d'un contact
- Préparation d'une action
- En attente de confirmation
- Exécution sécurisée
- Vérification de la transaction

---

# SIKA STATES

Les états importants sont :

idle

processing

agentWorking

clarificationRequired / ambiguityAsked

waitingVoiceConfirmation

securityValidation

executingAction

reconciling

completed

error

Règle critique :

UNKNOWN_RESULT ≠ ERROR

UNKNOWN_RESULT doit être géré avec :

SikaState.reconciling

L'utilisateur doit voir un message rassurant indiquant que le statut de la transaction est en cours de vérification.

---

# ACTIONS FINANCIÈRES

Une seule action financière doit être confirmable à la fois.

Le système utilise notamment :

activeActionId

obsoleteActionIds

Si une nouvelle action remplace une ancienne :

ancienne action
→ obsolete

nouvelle action
→ active

Une action obsolete ne doit jamais pouvoir être confirmée.

Même si un ancien widget tente d'envoyer une confirmation, le Provider doit bloquer l'action.

Protéger également contre :

- double clic ;
- double confirmation ;
- double soumission.

---

# RÉUTILISATION DU CODE

Avant de créer un nouveau fichier ou composant :

1. Rechercher si une fonctionnalité similaire existe déjà.
2. Vérifier si elle peut être adaptée.
3. Préférer la réutilisation.
4. Éviter les doublons.

Ne pas supprimer un fichier sans vérifier :

- imports ;
- références ;
- usages ;
- tests éventuels.

Supprimer uniquement les fichiers réellement inutilisés ou remplacés.

---

# MÉTHODE DE TRAVAIL

Avant toute modification importante :

1. Lire les fichiers concernés.
2. Comprendre le flux existant.
3. Identifier les dépendances.
4. Vérifier si la fonctionnalité existe déjà.
5. Identifier la correction minimale.

Ensuite :

1. Modifier uniquement ce qui est nécessaire.
2. Vérifier les imports.
3. Vérifier les erreurs de compilation.
4. Exécuter les tests appropriés.

Pour Flutter :

flutter analyze

flutter test

Ne jamais dire qu'un test est réussi s'il n'a pas réellement été exécuté.

---

# OBJECTIF FINAL

L'objectif est de rendre SIKA démontrable de manière crédible.

Le parcours principal doit clairement fonctionner :

Utilisateur
↓
SIKA comprend la demande
↓
SIKA analyse
↓
SIKA utilise les outils nécessaires
↓
SIKA prépare une action
↓
L'utilisateur voit que l'action n'est PAS encore exécutée
↓
L'utilisateur confirme
↓
Biométrie
↓
/agent/confirm
↓
Orchestrator
↓
PayMeChap
↓
EXECUTED / FAILED / UNKNOWN_RESULT
↓
SIKA affiche correctement le résultat

---

# RÈGLE FINALE

La priorité actuelle est :

FONCTIONNEL > STABLE > TESTÉ > JOLI

Ne pas faire de refactor massif.

Ne pas casser les fonctionnalités déjà validées.

Toujours privilégier une correction progressive, minimale et compatible avec l'architecture actuelle.
