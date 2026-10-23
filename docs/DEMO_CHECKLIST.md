# Demo checklist — SIKA Pay (à faire avant chaque prise)

## Backend
- [ ] `backend/.env` contient `PAYPAL_CLIENT_ID` / `PAYPAL_CLIENT_SECRET` **sandbox** (jamais live).
- [ ] `PUBLIC_BASE_URL=http://<IP-LAN-du-PC>:8001`, joignable depuis le navigateur du téléphone (ouvrir `http://<IP>:8001/health` sur le téléphone).
- [ ] IA : `GEMINI_API_KEY` renseigné **ou** `gcloud auth application-default login` effectué. Vérifier qu'aucun quota 429 n'est actif (faire une requête test).
- [ ] `uvicorn app.main:app --host 0.0.0.0 --port 8001` lancé.
- [ ] `curl http://localhost:8001/api/v1/paypal/status` → `"configured": true`.
- [ ] (Recommandé, la veille) `python scripts/paypal_sandbox_e2e.py` réussi de bout en bout.

## Téléphone
- [ ] App installée avec `flutter run --release --dart-define=SIKA_API_URL=http://<IP>:8001` (ou APK construit avec ce `--dart-define`).
- [ ] Compte SIKA créé ; langue de l'app : **English** (Profil → paramètres) pour la vidéo.
- [ ] Empreinte digitale enregistrée sur le téléphone.
- [ ] Identifiants du compte **acheteur sandbox** prêts (email/mot de passe depuis developer.paypal.com → Sandbox Accounts).
- [ ] Navigateur par défaut : déconnecté de tout compte PayPal réel.
- [ ] Mode Ne pas déranger, batterie > 50 %, luminosité élevée, enregistrement d'écran actif.
- [ ] Historique vide ou propre (nouveau compte de test si besoin).

## Contenu
- [ ] Requête principale prête : *"Help me buy an Excel course without going over 50 dollars."*
- [ ] Requête hors budget (optionnelle) : *"Actually, the marketing course."*
- [ ] Aucune notification personnelle, aucun secret ni terminal visible.
- [ ] Musique libre de droits (ou aucune) ; aucun logo tiers ajouté au montage.

## Après tournage
- [ ] Vidéo < 3:00, sous-titres anglais, publique sur YouTube.
- [ ] Lien vidéo + dépôt public + **licence open source** ajoutés sur Devpost.
- [ ] Texte Devpost : fonctionnalités, outils IA (Gemini via Vertex AI / Gemini API), PayPal Orders v2 sandbox, ce qui a été construit pendant la période (voir `HACKATHON_PROGRESS.md`).
