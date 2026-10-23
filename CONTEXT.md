# CONTEXT — SIKA Pay

## Le produit
**SIKA Pay** est un agent de paiement IA mobile : l'utilisateur exprime une intention d'achat et un budget, l'agent (Gemini) cherche le produit, prépare un paiement **PayPal sandbox**, l'utilisateur confirme et approuve, puis le backend capture et vérifie le résultat réel auprès de PayPal.

Promesse : *Your AI. Your money. Your control.*

## Le concours
- **PayPal AI Hackathon 2026 — "Build what's next with PayPal and AI"** (<https://paypalaihackathon.devpost.com/>).
- Soumission : 1er oct. → **12 nov. 2026, 12 h 00 PT**. Jugement : 1er-15 déc. ; résultats vers le 21 déc.
- Exigences : intégration PayPal significative (sandbox) **et** IA significative, prototype fonctionnel, dépôt public **avec licence open source**, vidéo YouTube publique de moins de 3 min montrant l'app sur téléphone, matériel en anglais. Un projet existant est admis s'il a été **significativement mis à jour** pendant la période.
- Critères (à égalité) : implémentation technique, design, impact, innovation, présentation.
- Prix visés : Best Use of Agentic Commerce, Best Use of PayPal + AI, Best Demo Delivery.

## Historique
SIKA est né au Google "All Things Agentic" Hackathon (août 2026) comme assistant Mobile Money pour l'Afrique de l'Ouest, et n'y a pas été primé. Pour ce hackathon, la couche de paiement a été reconstruite autour de PayPal, et l'ancien fournisseur Mobile Money a été retiré. Voir `HISTORY.md`.

## Public et problème
Des utilisateurs qui découvrent le paiement numérique et l'achat en ligne : ils veulent comprendre ce qu'ils paient, respecter un budget et ne jamais laisser une IA dépenser sans contrôle.

## Principes non négociables
1. Sandbox uniquement : aucun argent réel.
2. Le modèle IA ne fixe jamais un montant, un destinataire ou un identifiant de commande.
3. Aucune opération financière sans confirmation explicite de l'utilisateur et sans vérification serveur auprès de PayPal.
4. « Créée », « approuvée » et « capturée » sont des états distincts ; seul un `COMPLETED` vérifié est présenté comme un paiement réussi.
5. Aucune donnée inventée : pas de faux solde, de faux produit présenté comme réel, ni de faux résultat PayPal.
6. Aucun secret dans le dépôt, l'APK, les logs ou la vidéo.

## Liens
- Dépôt : <https://github.com/dav9fulldev/sika-agent>
- Ancienne candidature : <https://devpost.com/software/sika-fzlh9s>
- PayPal Orders v2 : <https://developer.paypal.com/docs/api/orders/v2/>
