# AGENTIC ARCHITECTURE AUDIT - SIKA

## 1. Architecture Actuelle
- **Frontend Flutter** : Gère la saisie vocale/texte, l'affichage (cartes, alertes), l'authentification OAuth2/JWT et la biométrie en local.
- **Backend FastAPI** : Point d'entrée `/api/v1/sika/chat`.
- **SIKA Agent (`sika_agent.py`)** : Le "cerveau" actuel. Repose presque entièrement sur des conditions `if/elif` basées sur des mots clés ("envoie", "solde").
- **Intégration Gemini (`sika_ai.py`)** : Initialise le client Vertex AI `google-genai` mais l'utilise uniquement comme fallback ou pour parser des dates/noms, sans Function Calling dynamique.
- **Orchestrator (`orchestrator.py`)** : Couche de sécurité transactionnelle. Gère l'enregistrement des actions (`WAITING_CONFIRMATION`), le verrouillage (`with_for_update`), la réconciliation et les erreurs réseau (`UNKNOWN_RESULT`).
- **Tool Registry (`tool_registry.py`)** : Déclare les fonctions Python (ex: `prepare_transfer`) avec des niveaux de risque, mais l'agent LLM ne l'exploite pas directement.

## 2. Composants à Conserver
- **La couche d'Orchestration et de Base de Données** : `orchestrator.py`, `SikaActionModel`, la gestion des locks, la biométrie et les `UNKNOWN_RESULT` sont vitaux et ne doivent subir aucune modification risquée.
- **L'authentification et les routes** : `sika_router.py` et le middleware JWT.
- **Le `tool_registry.py`** : Son principe d'encapsulation est bon, il faut juste l'adapter pour exposer le schéma à Gemini.

## 3. Composants à Modifier
- **`sika_agent.py`** : Suppression de tous les `if/elif` de mots-clés. Remplacement par une **boucle agentique ReAct** (Raisonnement -> Tool -> Observation).
- **`sika_ai.py`** : Intégration du `Function Calling` via le paramètre `tools` du SDK `google-genai` et gestion des `function_calls` en retour.
- **Gestion de Mémoire** : Exploiter `SikaSessionModel` (déjà présent) pour sauvegarder les derniers messages (Mémoire conversationnelle) afin de gérer l'ambiguïté et les corrections ("Finalement mets 15 000").
- **System Prompt** : Le rendre dynamique pour inclure les soldes actuels et les contacts de l'utilisateur.

## 4. Risques de Régression
- **Contournement de Sécurité** : Risque que Gemini tente d'exécuter un paiement directement. *Mitigation : Ne jamais fournir d'outils de niveau EXECUTION (ex: `execute_transfer`) au LLM. Ne fournir que des outils PREPARATION (ex: `prepare_transfer`).*
- **Double Exécution** : Risque que l'agent génère deux requêtes de préparation. *Mitigation : Maintenir la contrainte d'attente sur `WAITING_CONFIRMATION` via l'Orchestrateur.*
- **Hallucinations** : Gemini pourrait inventer un montant ou un contact. *Mitigation : Prompts stricts interdisant l'invention de données financières.*

## 5. Plan d'Implémentation Résumé
1. **Tooling** : Traduire les schémas de `tool_registry.py` en schémas natifs `google-genai` (`types.Tool`).
2. **Mémoire & Contexte** : Implémenter la récupération/mise à jour de l'historique conversationnel dans `sika_agent.py`.
3. **Core ReAct** : Développer la boucle agentique dans `sika_agent.py` pour piloter Gemini.
4. **Validation Sécurisée** : Tester le flux où Gemini appelle `prepare_transfer`, reçoit une observation `WAITING_CONFIRMATION`, et rend la main à l'utilisateur.
