# HISTORY — SIKA → SIKA Pay

Chronologie du projet, des décisions et des leçons apprises.

## Août 2026 — SIKA v1 (Google "All Things Agentic" Hackathon)
- 16 août : initialisation, registre d'outils financiers et premiers tests.
- 26-31 août : design system « glass », authentification, KYC, agent Gemini (Vertex AI, `google-genai`), registre d'outils à trois niveaux de risque, confirmation humaine et biométrie, voix FR/EN, services Android (wake word, overlay).
- Paiement : intégration Mobile Money avec la plateforme du propriétaire (transferts préparés par l'agent, exécutés après confirmation).
- Soumission sur Devpost (<https://devpost.com/software/sika-fzlh9s>), **non primée**.
- Leçons tirées pour la suite :
  - les affirmations doivent être prouvées : le README annonçait « 115 tests 100 % PASS » alors que 2 tests échouaient et qu'un fichier bloquait ;
  - montrer l'agent agir de bout en bout plutôt que décrire l'architecture ;
  - une démo reproductible par les juges.

## 23 octobre 2026 — SIKA Pay (PayPal AI Hackathon 2026)
Objectif : une candidature au PayPal AI Hackathon (date limite le 12 nov. 2026 à 12 h PT), avec PayPal comme fournisseur de paiement central.

### Audit
- Exigences officielles lues sur Devpost (règles et page principale).
- Référence exécutée sur une copie intacte du commit `e0fcaea` : 2 échecs dans `test_crypto_and_input_security` et un blocage de `test_gemini_integration` (boucle ReAct infinie).
- Défauts de sécurité trouvés : AFC du SDK contournant le registre, `user_id` usurpable par le modèle, secret partenaire en dur, tests capables de purger la base configurée dans `.env`.

### Décisions
1. **Un seul parcours** : l'achat assisté sous budget (commerce agentique), sur PayPal Orders v2 en sandbox.
2. Le modèle **prépare** ; le backend **calcule, vérifie et exécute** ; l'utilisateur **confirme** dans SIKA, **approuve** sur PayPal puis **finalise** (« Pay now »). Aucun outil IA ne crée ni ne capture de paiement.
3. Catalogue de démonstration fictif (`SIKA Demo Store`), clairement étiqueté. Les appels PayPal sont réels (sandbox).
4. Aucun solde PayPal affiché (l'API Orders n'en fournit pas) : rien n'est inventé.
5. Sur demande explicite du propriétaire, **suppression complète de l'ancien fournisseur Mobile Money** : client API, routes wallets, outils de transfert, moteur hors ligne, UI wallets, tests et assets. Récupérable via l'historique Git.
6. Maquettes du propriétaire suivies (accueil, conversation, récapitulatif, approbation, résultat), sauf pour les produits de marque (Amazon, JBL), le solde inventé et le statut « Approuvé » présenté comme final.

### Réalisé
Voir `docs/HACKATHON_PROGRESS.md` (liste détaillée et preuves) et `docs/PAYPAL_HACKATHON_AUDIT.md`.

### Reste à faire (propriétaire)
- Créer l'application sandbox PayPal, renseigner `backend/.env`, lancer `backend/scripts/paypal_sandbox_e2e.py`.
- Choisir et ajouter une licence open source.
- Révoquer l'ancien secret partenaire présent dans l'historique Git.
- Tourner la vidéo (`docs/DEMO_SCRIPT.md`) et compléter la soumission Devpost.
