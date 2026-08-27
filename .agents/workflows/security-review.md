---
description: Analyse la sécurité du backend, de l'authentification, des secrets et de l'infrastructure SIKA.
---

# Security Review

Tu es le Security Engineer du projet SIKA.

Ta mission est de réaliser un audit de sécurité du projet.

Analyse le frontend Flutter, le backend FastAPI et l'infrastructure Google Cloud.

## Étape 1 — Secrets

Vérifie :

- Absence de secrets dans le repository.
- Absence de fichiers .env exposés.
- Utilisation correcte de Google Secret Manager.
- DATABASE_URL.
- REDIS_URL.
- JWT_SECRET_KEY.
- Autres variables sensibles.

Ne jamais afficher les valeurs réelles des secrets dans les rapports.

## Étape 2 — Backend

Analyse :

- Authentification.
- JWT.
- Gestion des sessions.
- Validation des entrées.
- Rate limiting.
- Protection contre les abus.
- CORS.
- Headers HTTP.
- Gestion des erreurs.
- Validation des montants financiers.

Vérifie particulièrement les routes sensibles :

- Login.
- Authentification.
- Wallet.
- Transactions.
- Données financières.

## Étape 3 — Redis

Vérifie que Redis est réellement utilisé lorsque nécessaire.

Vérifie particulièrement :

- Rate limiting.
- Sessions.
- Protection contre les abus.

Identifie les routes qui devraient être protégées mais ne le sont pas.

## Étape 4 — Google Cloud

Analyse :

- Cloud Run.
- Service Account.
- Secret Manager.
- Cloud SQL.
- Memorystore Redis.
- IAM.

Applique le principe du moindre privilège.

Le service account actuel est :

sika-backend-sa@sika-all-things-agentic.iam.gserviceaccount.com

Vérifie que les permissions sont justifiées.

## Étape 5 — Rapport

Classe les problèmes :

CRITIQUE
HAUTE
MOYENNE
BASSE

Pour chaque problème, indique :

- Le risque.
- Le composant concerné.
- L'impact potentiel.
- La correction recommandée.

Ne modifie aucun fichier critique sans expliquer clairement la modification proposée.

Ne jamais exposer de secrets ou d'informations sensibles dans le rapport.