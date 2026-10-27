# Audit — SIKA → SIKA Pay (PayPal AI Hackathon 2026)

Date de l'audit : 23 octobre 2026. Branche `main`, commit de départ `e0fcaea`, arbre de travail propre au départ.

Ce document distingue **ce qui a été vérifié** (lu dans le code ou exécuté), **ce qui reste inconnu** et **la stratégie retenue**.

---

## 1. Exigences officielles (vérifiées sur le site, 23 oct. 2026)

Sources : <https://paypalaihackathon.devpost.com/> et `/rules`, téléchargées et lues.

| Exigence | Détail officiel | Statut SIKA Pay |
|---|---|---|
| Période de soumission | 1er oct. 2026, 9 h 15 PT → **12 nov. 2026, 12 h 00 PT** | – |
| Intégration PayPal significative | « Meaningfully integrate at least one PayPal technology… (free sandbox) » | ✅ Orders v2 : création, vérification, capture et gestion des erreurs |
| IA significative | « Meaningfully incorporate AI » | ✅ Agent Gemini à function calling avec outils stricts |
| Prototype fonctionnel | Instructions complètes **ou** URL hébergée | ✅ Instructions dans le README et le guide sandbox |
| Projet existant | Autorisé s'il est **« significantly updated »** pendant la période, avec explication | ✅ Voir `HACKATHON_PROGRESS.md` |
| Dépôt public + licence open source visible | Obligatoire | ❌ **Aucun fichier LICENSE** : choix du propriétaire requis |
| Vidéo | < 3 min, YouTube public, montrant l'app sur l'appareil cible, sans marque ni musique tierce non autorisée | ⏳ Script prêt (`DEMO_SCRIPT.md`) ; séquences à filmer |
| Langue | Anglais, ou traduction anglaise | ✅ README, script et UI en EN/FR |
| Accès de test | Instructions, identifiants sandbox ou moyen d'en obtenir | ✅ Guide sandbox (les juges peuvent créer leurs identifiants) |

Critères notés à égalité : Technological Implementation, Design, Potential Impact, Innovation/Idea, Presentation. Prix ciblés : *Best Use of Agentic Commerce*, *Best Use of PayPal + AI*, *Best Demo Delivery* (honorable mentions, 5 000 $). Un projet ne peut gagner qu'un grand prix **ou** une mention honorable, plus éventuellement un prix sponsor.

**Leçon du hackathon précédent** (Google All Things Agentic, critères : Innovation & Operational Utility 40 %, Architectural Discipline 30 %…) : l'ancienne candidature affirmait « 115 tests, 100 % PASS » et une intégration « VERIFIED ». En réalité, sur le commit de départ, 2 tests échouaient et un fichier de tests bloquait indéfiniment (voir § 3). Cette version ne revendique que ce qui a été exécuté.

## 2. Architecture constatée au départ

- **Mobile** : Flutter 3, Riverpod, `local_auth`, STT/TTS, services Android (wake word, overlay). L'URL par défaut, même en debug, pointait vers Cloud Run (`app_config.dart`).
- **Backend** : FastAPI, SQLAlchemy et Alembic, SQLite en repli si PostgreSQL est injoignable, Redis optionnel.
- **Agent** : `SikaAIService.chat()` (boucle Gemini) avec `SikaToolRegistry` (3 niveaux de risque) et un moteur local `_chat_basic` d'environ 1 000 lignes. Google ADK figure dans `test_venv` mais **n'est pas utilisé** par le code applicatif ; l'appel se fait via `google-genai`.
- **Paiement** : PayMeChap (`paymechap_api_service.py`) appelé par `prepare_transfer` → `/agent/confirm` → `execute_payout`. Wave, Orange et MTN n'étaient que des stubs non vérifiés.
- **Session et identité** : JWT HS256, révocation, rate limits, journal `sika_action_events`.

## 3. Contrôles exécutés au départ (commit `e0fcaea`, copie intacte via `git worktree`)

| Fichier | Résultat réel |
|---|---|
| 13 fichiers sur 14 | ✅ passés (dont `test_abuse` en 60 s et `test_wallet_routes` en 46 s, ralentis par des tentatives de connexion Redis) |
| `test_crypto_and_input_security.py` | ❌ **2 échecs** : mock `execute_payout` sans le paramètre `sender_phone` |
| `test_gemini_integration.py` | ❌ **bloqué > 150 s** : boucle ReAct infinie (`step` jamais incrémenté, `MagicMock.function_calls` toujours vrai) |
| `flutter analyze` | non mesuré au départ ; 0 problème après les modifications |

## 4. Défauts et risques identifiés (et traitement)

| # | Constat | Traitement |
|---|---|---|
| R1 | Boucle ReAct infinie possible (`step` jamais incrémenté) | Corrigé : 5 étapes maximum, testé (`test_react_loop_is_bounded`) |
| R2 | AFC (automatic function calling) du SDK actif : les outils étaient exécutés **hors** du registre | AFC désactivé ; chaque outil passe par le registre |
| R3 | Le `user_id` proposé par le modèle était accepté s'il était renseigné (risque d'accès inter-utilisateurs) | `user_id` toujours imposé par le serveur ; testé |
| R4 | **Secret partenaire PayMeChap en dur** dans le code, donc dans l'historique public | Code supprimé. ⚠️ Le secret reste dans l'historique Git : **à révoquer côté PayMeChap** |
| R5 | Les tests font `drop_all()` sur le `DATABASE_URL` de `.env` (`127.0.0.1:5433`, potentiellement un proxy Cloud SQL) | `conftest.py` impose une base SQLite jetable |
| R6 | L'annulation côté mobile n'appelait jamais `/agent/cancel` | Flux supprimé ; l'annulation PayPal appelle le backend |
| R7 | Détection de langue : « I want to buy a course » classé en français | Vocabulaire commerce ajouté ; testé |
| R8 | Revendications de tests non vérifiées dans le README | README réécrit avec les chiffres mesurés |
| R9 | Test Alembic dépendant de l'ordre de `glob()` | Corrigé (migration initiale identifiée par `down_revision=None`) |

## 5. Inconnus / non vérifiés

- **Flux sandbox réel** : ✅ exécuté le 24 oct. 2026 avec `backend/scripts/paypal_sandbox_e2e.py` et une application sandbox dédiée. Commande `9PJ70960RC924761S` créée (`PAYER_ACTION_REQUIRED`), approuvée par le compte acheteur sandbox, statut `APPROVED` vérifié, capture `25J37924GR192080C` `COMPLETED` pour 49.00 USD, seconde capture refusée (`already_completed`). Résultat confirmé indépendamment par `GET /v2/checkout/orders/{id}`. Non encore exécuté : le même flux depuis l'application mobile sur téléphone physique.
- **Gemini réel** : vérifié en direct via Vertex AI (projet `sika-all-things-agentic`) sur quatre requêtes : préparation conforme, refus hors budget avec alternatives, question en cas d'ambiguïté, réponse en français. Une requête a reçu un `429 RESOURCE_EXHAUSTED` (quota Vertex), puis le repli déterministe a pris le relais.
- **APK** : compilation debug lancée (voir rapport final) ; non testée sur téléphone physique dans cette session.
- La vidéo et le dépôt public restent à produire par le propriétaire.

## 6. Stratégie retenue

**Un seul parcours exceptionnel** : *achat assisté sous budget* (commerce agentique), avec PayPal Orders v2 comme unique fournisseur.

1. Le modèle comprend la demande et utilise des outils stricts (recherche, préparation, statut). **Aucun outil ne crée ni ne capture de paiement.**
2. Le backend calcule le prix, vérifie le budget, la devise et les plafonds, lie la confirmation à une empreinte, crée la commande, vérifie `APPROVED` et capture de façon idempotente.
3. L'app affiche les états réels (préparé, commande créée, approuvée, capturée), la provenance des informations et le journal d'audit.
4. **PayMeChap a été entièrement retiré** à la demande du propriétaire (code, tests, assets, configuration, documentation), ainsi que le module Mobile Money qui en dépendait (routeur wallets, stubs Wave/Orange/MTN, outils de transfert, moteur `_chat_basic`). Tout reste récupérable dans l'historique Git.

Outils sponsors : aucun ajouté. Ni Render (hébergement), ni Postman (collection), ni AG Grid n'étaient nécessaires au parcours ; ce sont des options à évaluer plus tard. Le catalogue de produits est un jeu de démonstration clairement étiqueté, faute de source réelle accessible sans compte marchand (Channel3 nécessiterait une clé ; non évalué).
