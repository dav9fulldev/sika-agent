import os
import re
import json
import logging
from typing import Dict, Any, Optional, List, Tuple

from google import genai

logger = logging.getLogger(__name__)


class SikaAIService:
    """
    Service IA principal de SIKA.

    Architecture :
    - Gemini via Vertex AI
    - Authentification Google Cloud (ADC)
    - Pas de GEMINI_API_KEY
    - Fallback vers le moteur métier local si Gemini est indisponible
    """

    def __init__(self):
        self.provider = "vertex_ai"

        # Projet Google Cloud
        self.project = os.getenv(
            "GOOGLE_CLOUD_PROJECT",
            "sika-all-things-agentic"
        )

        # Gemini peut être appelé avec location=global
        self.location = os.getenv(
            "GOOGLE_CLOUD_LOCATION",
            "global"
        )

        # Modèle Gemini utilisé par SIKA
        self.model = os.getenv(
            "GEMINI_MODEL",
            "gemini-3.5-flash"
        )

        self.client = None

        self._init_gemini_client()

    @property
    def use_gemini(self) -> bool:
        """Retourne True si le client Gemini Vertex AI est disponible."""
        return self.client is not None

    def _init_gemini_client(self):
        """
        Initialise Gemini via Vertex AI.

        Aucune GEMINI_API_KEY n'est utilisée.

        L'authentification repose sur :
        - Application Default Credentials
        - gcloud auth application-default login en local
        - Service Account sur Cloud Run
        """

        try:
            self.client = genai.Client(
                vertexai=True,
                project=self.project,
                location=self.location,
            )

            logger.info(
                "🤖 SIKA connecté à Gemini via Vertex AI | "
                f"project={self.project} | "
                f"location={self.location} | "
                f"model={self.model}"
            )

        except Exception as e:
            self.client = None

            logger.warning(
                "⚠️ Impossible d'initialiser Gemini via Vertex AI : "
                f"{e}. Le fallback SIKA reste actif."
            )

    def detect_language(self, message: str) -> str:
        """
        Détection dynamique et déterministe de la langue (Anglais 'en' ou Français 'fr').
        Ne dépend d'aucun profil statique en BDD.
        """
        if not message or not message.strip():
            return "fr"

        msg_lower = message.lower()

        # Expressions et motifs forts anglais
        en_phrases = [
            "what's my", "what is my", "whats my", "how much", "how's my", "how is my",
            "my balance", "total balance", "recent spending", "recent expenses",
            "send ", "transfer ", "check my", "show me", "can you", "please ",
            "what can you do", "who are you"
        ]
        # Expressions et motifs forts français
        fr_phrases = [
            "quel est", "quelle est", "quels sont", "quelles sont", "combien j'ai",
            "combien de", "combien sur", "mon solde", "solde total", "mes dépenses",
            "mes depenses", "dépenses récentes", "envoie ", "envoyer ", "transférer ",
            "que peux-tu faire", "qui es-tu"
        ]

        en_score = sum(3 for p in en_phrases if p in msg_lower)
        fr_score = sum(3 for p in fr_phrases if p in msg_lower)

        # Mots-clés individuels
        english_words = {
            "what", "what's", "whats", "how", "much", "is", "my", "total", "balance",
            "check", "spending", "spent", "expenses", "expense", "send", "transfer",
            "savings", "safe", "deposit", "withdraw", "hello", "hi", "hey", "please",
            "can", "you", "i", "to", "for", "from", "show", "me", "recent", "analyze",
            "analysis", "money", "wallet", "wallets", "account", "accounts", "good",
            "morning", "evening", "thanks", "thank"
        }

        french_words = {
            "quel", "quelle", "quels", "quelles", "est", "sont", "mon", "ma", "mes",
            "solde", "soldes", "combien", "dépense", "dépenses", "dépensé", "depense",
            "depenses", "envoie", "envoyer", "transférer", "transferer", "transfert",
            "épargne", "epargne", "coffre", "coffres", "bonjour", "salut", "bonsoir",
            "coucou", "retrait", "retirer", "verser", "compte", "comptes", "portefeuille",
            "portefeuilles", "analyse", "analyser", "récent", "recents", "récentes", "recentes",
            "merci", "argent", "fonds"
        }

        tokens = set(re.findall(r"\b[a-zA-Z'’àâäéèêëîïôöùûüç]+\b", msg_lower))
        en_score += sum(1 for t in tokens if t in english_words)
        fr_score += sum(1 for t in tokens if t in french_words)

        if en_score > fr_score:
            return "en"
        return "fr"

    def _is_english(self, message: str) -> bool:
        """Vérifie si le message est en anglais."""
        return self.detect_language(message) == "en"

    def _format_currency(
        self,
        amount: float,
        context: Dict[str, Any]
    ) -> str:
        """
        Formate un montant selon la devise active du runtime.
        Préserve exactement le montant sans le convertir, 
        et utilise le symbole du contexte (provenance des données stricte).
        """
        code = context.get("currency_code")
        symbol = context.get("currency_symbol")
        
        if not symbol and not code:
            # If absolutely no currency is given, just format the number
            return f"{int(amount):,}".replace(",", " ")
            
        display_currency = symbol if symbol else code
        return f"{int(amount):,} {display_currency}".replace(",", " ").strip()

    def _extract_action(
        self,
        response: str,
        user_message: str
    ) -> Tuple[Optional[str], Optional[Dict[str, Any]]]:
        """
        Détecte une intention d'action financière.
        """

        res_lower = response.lower()
        msg_lower = user_message.lower()

        transfer_keywords = [
            "transfert",
            "transférer",
            "envoie",
            "envoyer",
            "transfer",
            "rebalance",
        ]

        if any(
            word in msg_lower or word in res_lower
            for word in transfer_keywords
        ):
            return (
                "prepare_transfer",
                {},
            )

        expense_keywords = [
            "dépense",
            "dépensé",
            "acheté",
            "spent",
            "buy",
            "purchase",
        ]

        if any(
            word in msg_lower or word in res_lower
            for word in expense_keywords
        ):
            return (
                "add_transaction",
                {}
            )

        return None, None

    # ------------------------------------------------------------------
    # Providers dont l'intégration est vérifiée et peut être appelée.
    # Les providers NOT_VERIFIED ne doivent jamais être appelés.
    # ------------------------------------------------------------------
    _VERIFIED_PROVIDERS: frozenset = frozenset({"paymechap"})

    def _select_wallet(
        self,
        wallets: List[Dict[str, Any]],
        user_message: str,
    ) -> Tuple[Optional[Dict[str, Any]], Optional[str]]:
        """
        Sélectionne le wallet approprié selon les règles métier SIKA.

        Retourne (wallet, None) si sélection claire.
        Retourne (None, message_clarification) si clarification nécessaire.
        Retourne (None, message_indisponibilité) si provider NOT_VERIFIED.

        Règles :
          - 0 wallet  → Aucun portefeuille connecté.
          - 1 wallet  → sélection automatique (VERIFIED seulement).
          - N wallets avec provider mentionné → sélection par provider.
            Si plusieurs wallets ont le même provider et ne sont pas distingués → clarification.
          - N wallets sans provider → demande de clarification (ask_wallet).
          - Provider mentionné mais NOT_VERIFIED → indisponibilité.
          - Jamais wallets[0] comme fallback arbitraire.
        """
        msg_lower = user_message.lower()

        if not wallets:
            return None, "Aucun portefeuille connecté."

        # 1. Chercher si un compte ou provider spécifique est mentionné dans le message
        matching_wallets: List[Dict[str, Any]] = []
        for w in wallets:
            prov = (w.get("provider") or "").lower()
            acc = str(w.get("account_number") or w.get("external_wallet_id") or "").lower()
            if acc and acc in msg_lower:
                matching_wallets.append(w)
            elif prov and prov in msg_lower:
                matching_wallets.append(w)

        if matching_wallets:
            if len(matching_wallets) == 1:
                selected = matching_wallets[0]
                prov_lower = (selected.get("provider") or "").lower()
                if prov_lower not in self._VERIFIED_PROVIDERS:
                    provider_display = selected.get("provider", prov_lower)
                    return None, (
                        f"Le portefeuille {provider_display} n'est actuellement "
                        "pas disponible dans SIKA."
                    )
                return selected, None

            # Plusieurs wallets correspondent au provider mentionné (ex: 2 PayMeChap sans compte précisé)
            # Vérifier si l'un d'eux est distingué par son numéro de compte
            account_matches = [
                w for w in matching_wallets
                if str(w.get("account_number") or w.get("external_wallet_id") or "").lower() in msg_lower
                and str(w.get("account_number") or w.get("external_wallet_id") or "").strip()
            ]
            if len(account_matches) == 1:
                selected = account_matches[0]
                prov_lower = (selected.get("provider") or "").lower()
                if prov_lower not in self._VERIFIED_PROVIDERS:
                    provider_display = selected.get("provider", prov_lower)
                    return None, (
                        f"Le portefeuille {provider_display} n'est actuellement "
                        "pas disponible dans SIKA."
                    )
                return selected, None

            first_prov = matching_wallets[0].get("provider", "PayMeChap")
            accounts = ", ".join([
                str(w.get("account_number") or w.get("external_wallet_id") or w.get("id"))
                for w in matching_wallets
            ])
            return None, (
                f"Vous avez plusieurs portefeuilles {first_prov} ({accounts}). "
                "Quel portefeuille souhaitez\u2011vous utiliser ?"
            )

        # 2. Aucun provider mentionné dans le message
        if len(wallets) == 1:
            prov_lower = (wallets[0].get("provider") or "").lower()
            if prov_lower not in self._VERIFIED_PROVIDERS:
                provider_display = wallets[0].get("provider", prov_lower)
                return None, (
                    f"Le portefeuille {provider_display} n'est actuellement "
                    "pas disponible dans SIKA."
                )
            return wallets[0], None

        # Plusieurs wallets, aucun provider mentionné → clarification
        prov_options = ", ".join(
            sorted({w.get("provider") for w in wallets if w.get("provider")})
        )
        return None, (
            f"Vous avez plusieurs portefeuilles actifs ({prov_options}). "
            "Quel portefeuille souhaitez\u2011vous utiliser ?"
        )

    def _extract_transfer_amount(self, message: str) -> float:
        """
        Extrait et normalise le montant d'un transfert depuis le message utilisateur.
        Supporte les formats :
          - '10 000 FCFA', '10000 FCFA', '10.000 FCFA', '10,000 FCFA'
          - '10000', '10 000'
          - Montants négatifs '-100 FCFA'
        """
        # 1. Vérifier d'abord les montants explicitement négatifs
        neg_match = re.search(r"-\s*(\d+[\d\s.,]*)", message)
        if neg_match:
            return -1.0

        # 2. Chercher avec devise (FCFA, XOF, F, etc.)
        match_unit = re.search(r"(\d+[\d\s.,]*)\s*(?:fcfa|xof|f\b|francs?)", message, re.IGNORECASE)
        if match_unit:
            raw_str = match_unit.group(1).strip()
        else:
            # 3. Chercher le premier groupe numérique
            match_num = re.search(r"\b(\d+[\d\s.,]*)\b", message)
            if match_num:
                raw_str = match_num.group(1).strip()
            else:
                return 0.0

        # Nettoyage des espaces
        cleaned = raw_str.replace(" ", "")
        # Si format millier 10.000 ou 10,000 (ex: 3 chiffres après le séparateur sans autre décimale)
        if re.match(r"^\d{1,3}[.,]\d{3}$", cleaned):
            cleaned = re.sub(r"[.,]", "", cleaned)
        else:
            cleaned = cleaned.replace(",", ".")

        try:
            return float(cleaned)
        except (ValueError, TypeError):
            return 0.0

    def _chat_basic(
        self,
        user_message: str,
        financial_context: Dict[str, Any],
        user_firstname: str,
        is_english: bool,
        user_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Moteur métier local SIKA.

        Ce moteur reste fonctionnel même si Vertex AI
        ou Gemini devient temporairement indisponible.
        """

        msg_lower = user_message.lower()

        action, action_data = self._extract_action(
            "",
            user_message
        )

        # =========================================================
        # RÉCUPÉRATION DES WALLETS CONNECTÉS
        # =========================================================

        active_wallets = [
            wallet
            for wallet in financial_context.get("wallets", [])
            if wallet.get("is_active", True)
        ]

        total_balance_fcfa = sum(
            wallet.get("balance", 0.0)
            for wallet in active_wallets
        )

        fmt_total = self._format_currency(
            total_balance_fcfa,
            financial_context,
        )

        # =========================================================
        # 1. CONSULTATION DU SOLDE
        # =========================================================

        financial_intent_keywords = [
            "solde",
            "combien j'ai",
            "combien sur",
            "mon solde",
            "total balance",
            "how much money",
            "combien d'argent",
            "état de mes comptes",
            "portefeuilles",
            "wallet balance",
            "my balance",
            "balance",
            "what is my balance",
            "what's my balance",
            "whats my balance",
        ]

        if any(
            keyword in msg_lower
            for keyword in financial_intent_keywords
        ):

            if not active_wallets:

                if is_english:

                    response = (
                        f"Hi {user_firstname}! "
                        "You don't have any connected wallets yet. "
                        "Connect PayMeChap, Wave, Orange Money "
                        "or MTN MoMo to let me help you manage them."
                    )

                    suggestions = [
                        "Connect a wallet",
                        "How does SIKA work?",
                        "Help",
                    ]

                else:

                    response = (
                        f"Salut {user_firstname} ! "
                        "Tu n'as encore aucun portefeuille connecté. "
                        "Connecte PayMeChap, Wave, Orange Money "
                        "ou MTN MoMo pour que je puisse t'aider "
                        "à gérer tes finances."
                    )

                    suggestions = [
                        "Connecter un compte",
                        "Comment fonctionne SIKA ?",
                        "Aide",
                    ]

            elif len(active_wallets) == 1:
                # Un seul wallet : sélection automatique
                selected_w, wallet_clarif = self._select_wallet(active_wallets, user_message)
                if wallet_clarif:
                    # Provider NOT_VERIFIED
                    return {
                        "response": wallet_clarif,
                        "action": "wallet_unavailable",
                        "action_data": {"provider": active_wallets[0].get("provider")},
                        "sentiment": "neutral",
                        "suggestions": [],
                        "provider": "VERTEX_AI",
                        "model": self.model,
                    }
                fmt_bal = self._format_currency(
                    selected_w.get("balance", 0.0), financial_context
                )
                prov_name = selected_w.get("provider", "Wallet")
                acc = selected_w.get("account_number", "")
                acc_info = f" ({acc})" if acc else ""
                response = (
                    f"Ton solde {prov_name}{acc_info} est de {fmt_bal}."
                    if not is_english
                    else f"Your {prov_name}{acc_info} balance is {fmt_bal}."
                )
                suggestions = [
                    "Voir mes dépenses récentes",
                    "Effectuer un transfert",
                ] if not is_english else [
                    "View recent expenses",
                    "Make a transfer",
                ]

            else:
                # Plusieurs wallets
                selected_w, wallet_clarif = self._select_wallet(active_wallets, user_message)
                if wallet_clarif:
                    # Provider NOT_VERIFIED ou clarification nécessaire
                    action_key = (
                        "ask_wallet"
                        if "plusieurs" in wallet_clarif or "multiple" in wallet_clarif.lower()
                        else "wallet_unavailable"
                    )
                    return {
                        "response": wallet_clarif,
                        "action": action_key,
                        "action_data": {"available_wallets": [w.get("provider") for w in active_wallets]},
                        "sentiment": "neutral",
                        "suggestions": [],
                        "provider": "VERTEX_AI",
                        "model": self.model,
                    }
                # Provider sélectionné
                fmt_bal = self._format_currency(
                    selected_w.get("balance", 0.0), financial_context
                )
                prov_name = selected_w.get("provider", "Wallet")
                acc = selected_w.get("account_number", "")
                acc_info = f" ({acc})" if acc else ""
                response = (
                    f"Ton solde {prov_name}{acc_info} est de {fmt_bal}."
                    if not is_english
                    else f"Your {prov_name}{acc_info} balance is {fmt_bal}."
                )
                suggestions = [
                    "Voir mes dépenses récentes",
                    "Effectuer un transfert",
                ] if not is_english else [
                    "View recent expenses",
                    "Make a transfer",
                ]

            return {
                "response": response,
                "action": "get_total_balance",
                "action_data": action_data,
                "sentiment": "positive",
                "suggestions": suggestions,
                "provider": "VERTEX_AI",
                "model": self.model,
            }

        # =========================================================
        # 2. COFFRES D'ÉPARGNE
        # =========================================================

        coffre_keywords = [
            "coffre",
            "safe",
            "étude",
            "etude",
            "déposer",
            "depot",
            "dépôt",
            "deposit",
            "deposited",
            "withdraw",
            "withdrawn",
            "retrait",
            "retirer",
            "épargne",
            "epargne",
            "verser",
            "ajouter au coffre",
        ]

        if any(
            keyword in msg_lower
            for keyword in coffre_keywords
        ):

            from .wallet_integrations.paymechap_api_service import (
                paymechap_api_service
            )

            numbers = re.findall(
                r"\d+[\d\s,.]*",
                user_message,
            )

            raw_amount = 10000.0

            if numbers:

                try:

                    clean_num_str = (
                        numbers[0]
                        .replace(" ", "")
                        .replace(",", "")
                    )

                    if clean_num_str.count(".") > 1:

                        clean_num_str = clean_num_str.replace(
                            ".",
                            ""
                        )

                    parsed_value = float(
                        clean_num_str
                    )

                    if parsed_value > 0:

                        raw_amount = parsed_value

                except Exception:

                    logger.warning(
                        "Impossible d'extraire le montant "
                        "du message utilisateur."
                    )

            is_deposit_action = any(
                keyword in msg_lower
                for keyword in [
                    "déposer",
                    "depot",
                    "dépôt",
                    "deposit",
                    "deposited",
                    "verser",
                    "ajouter",
                    "mettre",
                ]
            )

            is_withdraw_action = any(
                keyword in msg_lower
                for keyword in [
                    "withdraw",
                    "withdrawn",
                    "retrait",
                    "retirer",
                    "récupérer",
                    "cassage",
                    "casse",
                    "sortir",
                ]
            )

            active_paymechap_wallets = [
                wallet
                for wallet in active_wallets
                if "paymechap"
                in wallet.get(
                    "provider",
                    ""
                ).lower()
            ]

            target_account = (
                active_paymechap_wallets[0].get(
                    "account_number"
                )
                if active_paymechap_wallets
                else financial_context.get(
                    "account_number",
                    ""
                )
            )

            live_coffres = (
                paymechap_api_service.fetch_user_coffres(
                    "",
                    account_number=target_account,
                )
            )

            coffre_item: Dict[str, Any] = {}

            if live_coffres:

                for coffre in live_coffres:

                    coffre_name = str(
                        coffre.get("nom", "")
                    ).lower()

                    if coffre_name in msg_lower:

                        coffre_item = coffre
                        break

                if not coffre_item:

                    coffre_item = live_coffres[0]

            target_coffre_id = coffre_item.get("id")

            coffre_name = (
                coffre_item.get("nom")
                or "Épargne"
            )

            coffre_balance = float(
                coffre_item.get("solde")
                or 0.0
            )

            coffre_target = float(
                coffre_item.get("objectif")
                or 0.0
            )

            # -----------------------------------------------------
            # RETRAIT
            # -----------------------------------------------------

            if (
                is_withdraw_action
                and target_coffre_id is not None
            ):

                formatted_balance = self._format_currency(
                    coffre_balance,
                    financial_context,
                )

                formatted_target = self._format_currency(
                    coffre_target,
                    financial_context,
                )

                percentage = (
                    coffre_balance
                    / coffre_target
                    * 100
                    if coffre_target > 0
                    else 0.0
                )

                if is_english:

                    response = (
                        f"Your '{coffre_name}' safe currently "
                        f"holds {formatted_balance} out of "
                        f"{formatted_target} "
                        f"({percentage:.1f}% reached). "
                        "Withdrawal from the safe is not yet "
                        "available through the PayMeChap API."
                    )

                    suggestions = [
                        "Check total balance",
                        "View savings goal",
                        "View recent expenses",
                    ]

                else:

                    response = (
                        f"Votre coffre '{coffre_name}' "
                        f"contient actuellement "
                        f"{formatted_balance} sur "
                        f"{formatted_target} "
                        f"({percentage:.1f}% atteint). "
                        "Le retrait depuis les coffres "
                        "n'est pas encore disponible "
                        "sur l'API PayMeChap."
                    )

                    suggestions = [
                        "Vérifier mon solde total",
                        "Voir mon objectif d'épargne",
                        "Voir mes dépenses",
                    ]

                return {
                    "response": response,
                    "action": "check_savings_goal",
                    "action_data": {
                        "coffre_id": target_coffre_id,
                        "amount": raw_amount,
                        "coffre_name": coffre_name,
                    },
                    "sentiment": "neutral",
                    "suggestions": suggestions,
                    "provider": "VERTEX_AI",
                    "model": self.model,
                }

            # -----------------------------------------------------
            # DÉPÔT
            # -----------------------------------------------------

            if (
                is_deposit_action
                and target_coffre_id is not None
            ):

                deposit_result = (
                    paymechap_api_service.deposit_to_coffre(
                        "",
                        coffre_id=target_coffre_id,
                        montant=raw_amount,
                        account_number=target_account,
                    )
                )

                updated_coffres = (
                    paymechap_api_service.fetch_user_coffres(
                        "",
                        account_number=target_account,
                    )
                )

                if updated_coffres:

                    updated_item = updated_coffres[0]

                    coffre_name = (
                        updated_item.get("nom")
                        or coffre_name
                    )

                    coffre_balance = float(
                        updated_item.get("solde")
                        or 0.0
                    )

                    coffre_target = float(
                        updated_item.get("objectif")
                        or 0.0
                    )

                formatted_deposit = self._format_currency(
                    raw_amount,
                    financial_context,
                )

                formatted_balance = self._format_currency(
                    coffre_balance,
                    financial_context,
                )

                formatted_target = self._format_currency(
                    coffre_target,
                    financial_context,
                )

                percentage = (
                    coffre_balance
                    / coffre_target
                    * 100
                    if coffre_target > 0
                    else 0.0
                )

                message = (
                    deposit_result.get("message")
                    or "OK"
                )

                if is_english:

                    response = (
                        f"Deposit of {formatted_deposit} completed. "
                        f"PayMeChap response: {message}. "
                        f"Your '{coffre_name}' safe now contains "
                        f"{formatted_balance} out of "
                        f"{formatted_target} "
                        f"({percentage:.1f}%)."
                    )

                    suggestions = [
                        "View savings goal",
                        "Check total balance",
                    ]

                else:

                    response = (
                        f"Dépôt de {formatted_deposit} effectué. "
                        f"Réponse PayMeChap : {message}. "
                        f"Votre coffre '{coffre_name}' contient "
                        f"maintenant {formatted_balance} sur "
                        f"{formatted_target} "
                        f"({percentage:.1f}%)."
                    )

                    suggestions = [
                        "Voir l'objectif d'épargne",
                        "Vérifier mon solde",
                    ]

                return {
                    "response": response,
                    "action": "deposit_to_coffre",
                    "action_data": {
                        "coffre_id": target_coffre_id,
                        "amount": raw_amount,
                        "coffre_name": coffre_name,
                    },
                    "sentiment": "positive",
                    "suggestions": suggestions,
                    "provider": "VERTEX_AI",
                    "model": self.model,
                }

            # -----------------------------------------------------
            # CONSULTATION DU COFFRE
            # -----------------------------------------------------

            formatted_balance = self._format_currency(
                coffre_balance,
                financial_context,
            )

            formatted_target = self._format_currency(
                coffre_target,
                financial_context,
            )

            percentage = (
                coffre_balance
                / coffre_target
                * 100
                if coffre_target > 0
                else 0.0
            )

            if is_english:

                response = (
                    f"Your '{coffre_name}' safe currently "
                    f"contains {formatted_balance} out of "
                    f"{formatted_target} "
                    f"({percentage:.1f}% of your target)."
                )

                suggestions = [
                    "Deposit into safe",
                    "Check total balance",
                    "View recent expenses",
                ]

            else:

                response = (
                    f"Votre coffre d'épargne '{coffre_name}' "
                    f"contient actuellement "
                    f"{formatted_balance} sur un objectif de "
                    f"{formatted_target} "
                    f"({percentage:.1f}% de votre objectif)."
                )

                suggestions = [
                    "Déposer dans le coffre",
                    "Vérifier mon solde",
                    "Voir mes dépenses",
                ]

            return {
                "response": response,
                "action": "check_savings_goal",
                "action_data": {
                    "coffre_id": target_coffre_id,
                    "amount": raw_amount,
                    "coffre_name": coffre_name,
                },
                "sentiment": "positive",
                "suggestions": suggestions,
                "provider": "VERTEX_AI",
                "model": self.model,
            }

        # =========================================================
        # 3. SALUTATIONS
        # =========================================================

        greeting_keywords = [
            "bonjour",
            "salut",
            "coucou",
            "bonsoir",
            "comment tu vas",
            "ça va",
            "ca va",
            "comment vas-tu",
            "tu vas bien",
            "est-ce que tu vas bien",
            "hello",
            "hi",
            "hey",
            "how are you",
            "say hello",
            "are you okay",
            "are you fine",
            "are you good",
            "you okay",
            "how are you doing",
            "what's up",
            "whats up",
        ]

        if any(
            keyword in msg_lower
            for keyword in greeting_keywords
        ):

            if is_english:

                response = (
                    f"Hello {user_firstname}! "
                    "I am ready to help you manage your finances. "
                    "What would you like to check today?"
                )

                suggestions = [
                    "How much money do I have in total?",
                    "Analyze my recent expenses",
                    "How is my savings goal progressing?",
                ]

            else:

                response = (
                    f"Bonjour {user_firstname} ! "
                    "Je suis prêt à t'aider à gérer tes finances. "
                    "Que souhaites-tu vérifier aujourd'hui ?"
                )

                suggestions = [
                    "Quel est mon solde total ?",
                    "Analyser mes dépenses récentes",
                    "Comment avance mon épargne ?",
                ]

            return {
                "response": response,
                "action": None,
                "action_id": None,
                "action_data": None,
                "sentiment": "positive",
                "suggestions": suggestions,
                "provider": "VERTEX_AI",
                "model": self.model,
                "requires_confirmation": False,
                "status": "PROCESSED",
                "language": "en" if is_english else "fr",
            }

        # =========================================================
        # 4. TRANSFERT
        # =========================================================

        if any(
            keyword in msg_lower
            for keyword in [
                "transfert",
                "envoie",
                "envoyer",
                "transférer",
                "paye",
                "kouamé",
                "transfer",
                "rebalance",
            ]
        ):
            # Resolve wallet according to business rules (0/1/multiple)
            from ..agent.tools import wallet_tools, transaction_tools
            wallets_result = wallet_tools.get_wallets(user_id=user_id)
            wallets = wallets_result.data.get("wallets", [])
            selected_wallet, wallet_msg = self._select_wallet(wallets, user_message)
            if wallet_msg:
                return {
                    "response": wallet_msg,
                    "action": "ask_wallet",
                    "action_data": {"available_wallets": [w.get("provider") for w in wallets]},
                    "sentiment": "neutral",
                    "suggestions": [],
                    "provider": "VERTEX_AI",
                    "model": self.model,
                }
            # Resolve recipient contact
            import re
            contact_match = re.search(r"(?:à|to)\s+([A-Za-z0-9_\-+]+)", user_message, re.IGNORECASE)
            contact_name = contact_match.group(1) if contact_match else None
            if not contact_name:
                return {
                    "response": "Veuillez préciser le destinataire du transfert.",
                    "action": "ask_contact",
                    "action_data": {},
                    "sentiment": "neutral",
                    "suggestions": [],
                    "provider": "VERTEX_AI",
                    "model": self.model,
                }
            contacts_res = wallet_tools.search_contact(contact_name)
            contacts = contacts_res.data.get("contacts", [])
            if not contacts:
                return {
                    "response": f"Je ne trouve pas '{contact_name}' dans vos contacts. Pouvez-vous préciser son numéro ou vérifier le nom du bénéficiaire ?",
                    "action": "ask_contact",
                    "action_data": {"query": contact_name},
                    "sentiment": "neutral",
                    "suggestions": [],
                    "provider": "VERTEX_AI",
                    "model": self.model,
                }
            if len(contacts) > 1:
                options = ", ".join([c.get("name", "") for c in contacts])
                return {
                    "response": f"Plusieurs contacts correspondent à '{contact_name}'. Veuillez préciser : {options}.",
                    "action": "ask_contact",
                    "action_data": {"candidates": contacts},
                    "sentiment": "neutral",
                    "suggestions": [],
                    "provider": "VERTEX_AI",
                    "model": self.model,
                }
            recipient = contacts[0]
            recipient_value = recipient.get("phone") or recipient.get("id") or recipient.get("name")
            # Extract amount with robust multi-format support
            amount = self._extract_transfer_amount(user_message)
            provider = selected_wallet.get("provider")
            # Prepare transfer (no execution yet)
            wallet_code = financial_context.get("wallet_currency_code") or "XOF"
            prepare_res = transaction_tools.prepare_transfer(
                provider=provider,
                amount=amount,
                recipient=recipient_value,
                currency=wallet_code,
            )
            if not prepare_res.success:
                return {
                    "response": prepare_res.error_message or "Erreur lors de la préparation du transfert.",
                    "action": "error",
                    "action_data": {},
                    "sentiment": "negative",
                    "suggestions": [],
                    "provider": "VERTEX_AI",
                    "model": self.model,
                }
            action_id = prepare_res.data.get("action_id")
            if action_id:
                from ..agent.orchestrator import sika_orchestrator
                numeric_uid = int(user_id) if user_id and str(user_id).isdigit() else 1
                sika_orchestrator.register_action(
                    action_id=action_id,
                    user_id=numeric_uid,
                    action_type="TRANSFER",
                    payload=prepare_res.data,
                )
            suggestions = ["Je confirme le transfert", "Annuler le transfert"]
            return {
                "response": prepare_res.data.get("summary", "Préparation du transfert prête."),
                "action": "prepare_transfer",
                "action_id": action_id,
                "action_data": prepare_res.data,
                "requires_confirmation": True,
                "status": "WAITING_CONFIRMATION",
                "should_speak": True,
                "sentiment": "neutral",
                "suggestions": suggestions,
                "provider": "VERTEX_AI",
                "model": self.model,
            }

        # =========================================================
        # 5. OBJECTIF D'ÉPARGNE
        # =========================================================

        if any(
            keyword in msg_lower
            for keyword in [
                "épargne",
                "objectif",
                "économiser",
                "avancement",
                "save",
                "savings",
                "goal",
                "de côté",
                "reçu",
            ]
        ):

            if (
                "combien" in msg_lower
                or "de côté" in msg_lower
                or "reçu" in msg_lower
            ):

                if is_english:

                    response = (
                        f"Based on your financial context, "
                        "setting aside some money could be a good option. "
                        "Would you like me to prepare a deposit?"
                    )

                    suggestions = [
                        "Deposit into safe",
                        "Check total balance",
                    ]

                else:

                    response = (
                        f"En tenant compte de ton contexte financier "
                        f"{user_firstname}, mettre de l'argent de côté "
                        "pourrait être une bonne option. "
                        "Souhaites-tu que je prépare le dépôt ?"
                    )

                    suggestions = [
                        "Déposer dans le coffre",
                        "Vérifier mon solde",
                    ]

            else:

                if is_english:

                    response = (
                        "I can help you analyze the progress "
                        "of your savings goal and recommend "
                        "the next action."
                    )

                    suggestions = [
                        "Check savings progress",
                        "Add money to savings",
                    ]

                else:

                    response = (
                        "Je peux analyser l'avancement de ton "
                        "objectif d'épargne et te recommander "
                        "la prochaine action."
                    )

                    suggestions = [
                        "Voir l'avancement",
                        "Ajouter à l'épargne",
                    ]

            return {
                "response": response,
                "action": "check_savings_goal",
                "action_data": action_data,
                "sentiment": "positive",
                "suggestions": suggestions,
                "provider": "VERTEX_AI",
                "model": self.model,
            }

        # =========================================================
        # 6. ANALYSE DES DÉPENSES
        # =========================================================

        if any(
            keyword in msg_lower
            for keyword in [
                "dépense",
                "dépensé",
                "acheté",
                "budget",
                "analyze",
                "recent",
                "expenses",
                "spending",
            ]
        ):

            if is_english:

                response = (
                    "I can analyze your recent spending "
                    f"based on your connected financial data. "
                    f"Your currently aggregated balance is "
                    f"{fmt_total}."
                )

                suggestions = [
                    "Set spending limit",
                    "View transaction history",
                ]

            else:

                response = (
                    "Je peux analyser tes dépenses récentes "
                    "à partir de tes données financières connectées. "
                    f"Ton solde agrégé actuel est de {fmt_total}."
                )

                suggestions = [
                    "Définir une limite",
                    "Voir l'historique",
                ]

            return {
                "response": response,
                "action": "get_spending_summary",
                "action_data": action_data,
                "sentiment": "neutral",
                "suggestions": suggestions,
                "provider": "VERTEX_AI",
                "model": self.model,
            }

        # =========================================================
        # 7. FALLBACK
        # =========================================================

        if is_english:

            response = (
                f"Sorry {user_firstname}, "
                "I didn't fully understand that. "
                "You can ask me about your balance, "
                "expenses, savings or transfers."
            )

            suggestions = [
                "How much money do I have in total?",
                "How is my savings goal progressing?",
                "Analyze my recent expenses",
            ]

        else:

            response = (
                f"Pardon {user_firstname}, "
                "je n'ai pas bien compris. "
                "Tu peux me demander ton solde, "
                "analyser tes dépenses, ton épargne "
                "ou préparer un transfert."
            )

            suggestions = [
                "Quel est mon solde total ?",
                "Comment avance mon épargne ?",
                "Analyser mes dépenses",
            ]

        return {
            "response": response,
            "action": None,
            "action_data": None,
            "sentiment": "neutral",
            "suggestions": suggestions,
            "provider": "VERTEX_AI",
            "model": self.model,
        }

    def _format_response(
        self,
        sika_response: str,
        user_message: str,
        financial_context: Dict[str, Any],
        is_english: bool,
    ) -> Dict[str, Any]:
        """Formate une réponse générée par Gemini."""

        # Clean markdown artifacts for clean UI/TTS rendering
        clean_response = sika_response.replace("**", "").replace("*", "")

        action, action_data = self._extract_action(
            sika_response,
            user_message,
        )

        return {
            "response": clean_response,
            "action": action,
            "action_data": action_data,
            "sentiment": "positive",
            "suggestions": [
                (
                    "How much money do I have in total?"
                    if is_english
                    else "Quel est mon solde total ?"
                ),
                (
                    "How is my savings goal progressing?"
                    if is_english
                    else "Comment avance mon épargne ?"
                ),
                (
                    "Analyze recent expenses"
                    if is_english
                    else "Analyser mes dépenses"
                ),
            ],
            "provider": "VERTEX_AI",
            "model": self.model,
        }

    def _is_pure_greeting(self, message: str) -> bool:
        """
        Détecte si un message utilisateur est une salutation pure sans intention financière explicite
        (ex: "hello", "bonjour", "salut", "hi", "coucou", "good morning", "hey sika").
        """
        if not message:
            return False
        clean = re.sub(r"[^\w\s]", "", message.lower()).strip()
        pure_greetings = {
            "hello", "hi", "hey", "good morning", "good afternoon", "good evening",
            "bonjour", "salut", "coucou", "bonsoir", "sika", "hey sika", "hello sika",
            "dis sika", "comment tu vas", "ça va", "ca va", "comment vas tu", "how are you",
            "what's up", "whats up", "yo"
        }
        if clean in pure_greetings:
            return True
        words = clean.split()
        if len(words) <= 3 and all(w in {"hello", "hi", "hey", "sika", "bonjour", "salut", "coucou", "bonsoir", "yo", "ca", "ça", "va"} for w in words):
            return True
        return False

    async def chat(
        self,
        user_message: str,
        financial_context: Optional[Dict[str, Any]] = None,
        conversation_history: Optional[List[Any]] = None,
        user_firstname: Optional[str] = None,
        user_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Point d'entrée principal SIKA (Agent Taskmaster).
        Utilise une boucle ReAct avec Function Calling dynamique.
        """
        context = financial_context or {}
        firstname = user_firstname or context.get("user_firstname") or "David"
        is_english = self._is_english(user_message)

        # Salutation pure : Réponse directe sans exécuter de transaction de l'historique
        if self._is_pure_greeting(user_message):
            return self._chat_basic(user_message, context, firstname, is_english, user_id=user_id)

        if not self.client:
            return self._chat_basic(user_message, context, firstname, is_english, user_id=user_id)

        from ..agent.tool_registry import tool_registry
        from google.genai import types

        # Some deployed revisions may not implement `get_gemini_tools` yet.
        # Use a safe fallback to build the list of safe tools when missing.
        try:
            safe_tools = tool_registry.get_gemini_tools()
        except AttributeError:
            safe_tools = []
            defs = getattr(tool_registry, "_definitions", {}) or {}
            for name, def_item in defs.items():
                # Accept READ_ONLY and CONFIRMATION_REQUIRED tools as safe
                if getattr(def_item, 'risk_level', None) and getattr(def_item.risk_level, 'value', '') in [
                    'READ_ONLY',
                    'CONFIRMATION_REQUIRED',
                ]:
                    func = getattr(tool_registry, '_tools', {}).get(name)
                    if func:
                        safe_tools.append(func)

        active_wallets = [w for w in context.get("wallets", []) if w.get("is_active", True)]
        total_balance = sum(w.get("balance", 0.0) for w in active_wallets)
        
        # 3-Tier Currency Architecture mapping
        display_code = context.get("display_currency_code") or "XOF"
        display_sym = context.get("display_currency_symbol") or "FCFA"
        wallet_code = context.get("wallet_currency_code") or "XOF"
        wallet_sym = context.get("wallet_currency_symbol") or "FCFA"
        
        context_str = f"Solde total brut des portefeuilles : {total_balance} {wallet_sym}\n"
        context_str += f"Devise d'affichage UI : {display_code} ({display_sym})\n"
        context_str += f"Devise de base du portefeuille : {wallet_code} ({wallet_sym})\n"
        context_str += "Comptes: " + ", ".join([f"{w.get('provider', 'Compte')} ({w.get('balance', 0.0)} {wallet_sym})" for w in active_wallets])

        lang_instruction = "Réponds UNIQUEMENT en anglais." if is_english else "Réponds UNIQUEMENT en français."

        system_instruction = f"""
            RÈGLE CRITIQUE — ACTIONS FINANCIÈRES ET TOOLS :

Tu es SIKA, un agent financier intelligent pour PayMeChap.
Utilisateur : {firstname}

Contexte financier de l'utilisateur :
{context_str}

RÈGLES STRICTES :
1. Tu dois aider l'utilisateur à comprendre ses finances, épargner, et transférer de l'argent.
2. N'invente JAMAIS un solde ou une transaction. Utilise les outils disponibles pour chercher l'information.
3. Si l'utilisateur demande d'envoyer, transférer ou effectuer une transaction d'argent avec un montant et un destinataire/numéro (ex: "effectue une transaction de 15000 F sur le numéro 0779996927" ou "envoie 5000 à Franck"), tu DOIS OBLIGATOIREMENT appeler immédiatement le tool `prepare_transfer(amount=..., recipient=..., provider='paymechap')`. Ne réponds JAMAIS par un simple texte sans appeler `prepare_transfer`.
4. Si une information est ambiguë (plusieurs contacts avec le même nom), pose une question courte pour clarifier avant d'agir. Ne demande PAS le numéro si tu l'as déjà trouvé.
5. Tu ne peux pas exécuter directement une transaction. Appelle `prepare_transfer`, cela mettra la transaction en attente de confirmation humaine.
6. Réponds de manière concise, naturelle et chaleureuse.
7. Tu ne dois JAMAIS inventer un `action_id` ni générer un identifiant commençant par "act_" dans une réponse texte si `prepare_transfer` n'a pas été appelé avec succès.
8. Ne génère jamais un texte du type "action_id : act_xxxxx" si `prepare_transfer` n'a pas été appelé et validé.
9. RÈGLE DES DEVISES : Gemini ne doit JAMAIS effectuer de conversion monétaire ou de calcul de taux de change. Si la devise d'affichage ({display_code}) est différente de la devise du portefeuille ({wallet_code}) et qu'aucun taux n'est fourni par le backend, annonce clairement les valeurs dans la devise de base du portefeuille ({wallet_code}) pour éviter toute incohérence.
10. RÈGLE SALUTATIONS : Si le message utilisateur est une simple salutation (ex: hello, bonjour, hi), réponds de façon chaleureuse et présente tes capacités d'assistance. N'appelle JAMAIS de tool financier (prepare_transfer, etc.), même si l'historique conversationnel mentionnait un transfert antérieur.
11. RÈGLE CONFIRMATION ET PAIEMENT : Tu ne dois JAMAIS dire à l'utilisateur d'ouvrir l'application PayMeChap pour valider. La validation sécurisée par biométrie (Face ID / empreinte) ou code PIN se fait DIRECTEMENT dans l'application SIKA sur la carte de confirmation qui s'affiche à l'écran.

LANGUE : {lang_instruction}
"""
        
        messages = []
        if conversation_history:
            for msg in conversation_history:
                messages.append(types.Content(
                    role="model" if msg.get("role") == "model" else "user",
                    parts=[types.Part.from_text(text=msg.get("content", ""))]
                ))
        
        messages.append(
            types.Content(role="user", parts=[types.Part.from_text(text=user_message)])
        )
        
        max_steps = 5
        step = 0
        final_response_text = ""
        action_detected = "chat"
        action_data_detected = None
        action_id = None
        agent_steps: list[dict] = []

        # Safe, observable labels for each tool — never expose internal reasoning
        _TOOL_LABELS = {
            "get_financial_context": "Analyse de votre situation financière",
            "search_contact": "Recherche du bénéficiaire",
            "prepare_transfer": "Préparation du transfert",
            "get_transaction_history": "Lecture de l'historique des transactions",
            "get_spending_analysis": "Analyse de vos dépenses",
            "get_budget_status": "Vérification de votre budget",
            "get_savings_goals": "Lecture de vos objectifs d'épargne",
        }
        
        while step < max_steps:
            try:
                response = await self.client.aio.models.generate_content(
                    model=self.model,
                    contents=messages,
                    config=types.GenerateContentConfig(
                        system_instruction=system_instruction,
                        tools=safe_tools,
                        temperature=0.2
                    )
                )
            except Exception as e:
                logger.error(f"Gemini error during generation: {e}")
                return self._chat_basic(user_message, context, firstname, is_english, user_id=user_id)

            # Add model response to history
            if getattr(response, 'candidates', None) and len(response.candidates) > 0:
                messages.append(response.candidates[0].content)

            if response.function_calls:
                # If there are function calls, execute them
                for call in response.function_calls:
                    logger.info(f"[SIKA AGENT] Gemini is calling tool: {call.name} with args: {call.args}")
                    
                    try:
                        # Execution via safe tool_registry
                        tool_res = tool_registry.execute(call.name, call.args)
                        res_dict = tool_res.to_dict()
                        step_status = "completed"
                    except Exception as e:
                        logger.error(f"Tool execution failed: {e}")
                        res_dict = {"error": str(e)}
                        step_status = "failed"

                    # Record this as a safe, observable agent step
                    agent_steps.append({
                        "id": f"step_{len(agent_steps) + 1}",
                        "type": call.name,
                        "label": _TOOL_LABELS.get(call.name, "Analyse en cours"),
                        "status": step_status,
                    })

                    # Append function result
                    messages.append(
                        types.Content(
                            role="function", 
                            parts=[
                                types.Part.from_function_response(
                                    name=call.name,
                                    response=res_dict
                                )
                            ]
                        )
                    )
                    
                    # If this was a CONFIRMATION_REQUIRED tool like prepare_transfer, we can yield back to the user
                    tool_def = tool_registry.get_definition(call.name)
                    if tool_def and tool_def.risk_level.value == "CONFIRMATION_REQUIRED":
                        action_detected = call.name
                        action_data_detected = res_dict.get("data", {})
                        action_id = action_data_detected.get("action_id")
                        if action_id:
                            # Enregistrement dans l'orchestrateur sécurisé SIKA
                            from ..agent.orchestrator import sika_orchestrator
                            sika_orchestrator.register_action(
                                action_id=action_id,
                                user_id=int(user_id) if user_id and user_id.isdigit() else 1,
                                action_type="TRANSFER" if call.name == "prepare_transfer" else "GENERIC_ACTION",
                                payload=action_data_detected
                            )
                            final_response_text = (
                                "I have prepared the transfer. Would you like to confirm?"
                                if is_english
                                else "J'ai préparé l'opération. Veux-tu confirmer ?"
                            )
                        break
                
                if action_detected == "prepare_transfer":
                    break
            else:
                # No function calls, so it's a final text response
                final_response_text = response.text

                # Defensive fallback: if the model produced a textual action_id like "act_...",
                # only accept it if we can verify the action exists (in-memory or DB).
                try:
                    match = re.search(r"(act_[A-Za-z0-9_-]{6,})", final_response_text)
                    if match and not action_id:
                        candidate = match.group(1)
                        from ..agent.orchestrator import sika_orchestrator

                        # 1) Check in-memory action store
                        if sika_orchestrator.action_store.get(candidate):
                            action_detected = "prepare_transfer"
                            action_id = candidate
                            action_data_detected = sika_orchestrator.action_store[candidate].get("result") or {}
                            final_response_text = (
                                "I have prepared the transfer. Would you like to confirm?"
                                if is_english
                                else "J'ai préparé l'opération. Veux-tu confirmer ?"
                            )
                        else:
                            # 2) Fallback: check persistent DB for a matching action
                            try:
                                from sqlalchemy.orm import Session
                                from ..database import engine
                                from ..models.sika_action import SikaActionModel

                                with Session(engine) as db:
                                    act = db.query(SikaActionModel).filter(SikaActionModel.action_id == candidate).first()
                                    if act:
                                        action_detected = "prepare_transfer"
                                        action_id = candidate
                                        try:
                                            action_data_detected = json.loads(act.payload_json) if act.payload_json else {}
                                        except Exception:
                                            action_data_detected = {}
                                        # Mirror into in-memory store for subsequent checks
                                        sika_orchestrator.action_store[candidate] = {
                                            "action_id": candidate,
                                            "user_id": act.user_id,
                                            "action_type": act.action_type,
                                            "status": act.status,
                                            "result": None,
                                        }
                                        final_response_text = (
                                            "I have prepared the transfer. Would you like to confirm?"
                                            if is_english
                                            else "J'ai préparé l'opération. Veux-tu confirmer ?"
                                        )
                            except Exception as e:
                                logger.warning(f"Fallback DB lookup failed for action_id {candidate}: {e}")
                except Exception as e:
                    logger.warning(f"Fallback action_id verification failed: {e}")

                break
                
        # Fallback déterministe : Si Gemini n'a pas appelé le tool mais que l'utilisateur demandait explicitement un transfert avec montant et numéro
        if not action_id and not self._is_pure_greeting(user_message):
            msg_lower = user_message.lower()
            transfer_keywords = ["transf", "envoi", "envoie", "envoyer", "paye", "payer", "effectue une transaction", "transferer", "verse", "verser", "send", "transfer"]
            if any(kw in msg_lower for kw in transfer_keywords):
                phone_match = re.search(r"(\+?225\s*)?(0[1-9]\d{8}|\d{10})", user_message.replace(" ", ""))
                amount_match = re.search(r"(\d+[\s\d]*)\s*(?:f|cfa|fcfa|xof|francs)?", user_message, re.IGNORECASE)
                if phone_match and amount_match:
                    try:
                        clean_amount_str = re.sub(r"\s+", "", amount_match.group(1))
                        amount_val = float(clean_amount_str)
                        recipient_phone = phone_match.group(0).replace(" ", "")
                        if amount_val > 0 and len(recipient_phone) >= 8:
                            logger.info(f"[SIKA DETERMINISTIC INTENT] Auto-executing prepare_transfer for {amount_val} to {recipient_phone}")
                            prep_res = tool_registry.execute("prepare_transfer", {
                                "amount": amount_val,
                                "recipient": recipient_phone,
                                "provider": "paymechap",
                                "currency": "XOF"
                            })
                            prep_dict = prep_res.to_dict()
                            if prep_res.success:
                                action_detected = "prepare_transfer"
                                action_data_detected = prep_dict.get("data", {})
                                action_data_detected["type"] = "transfer"
                                action_data_detected["action"] = "transfer"
                                action_id = action_data_detected.get("action_id")
                                if action_id:
                                    from ..agent.orchestrator import sika_orchestrator
                                    sika_orchestrator.register_action(
                                        action_id=action_id,
                                        user_id=int(user_id) if user_id and str(user_id).isdigit() else 1,
                                        action_type="TRANSFER",
                                        payload=action_data_detected
                                    )
                                    final_response_text = (
                                        f"I have prepared the transfer of {amount_val:,.0f} XOF to {recipient_phone}. Please confirm."
                                        if is_english
                                        else f"Bonjour ! J'ai bien préparé votre transfert de {amount_val:,.0f} XOF vers le numéro {recipient_phone}.\n\nVous pouvez désormais valider cette transaction en toute sécurité directement ici, sur la carte de confirmation qui s'affiche sur votre écran, à l'aide de votre empreinte digitale ou de votre code PIN."
                                    )
                    except Exception as prep_err:
                        logger.warning(f"Deterministic prepare_transfer fallback failed: {prep_err}")

        if not final_response_text:
            final_response_text = (
                "I was unable to complete the analysis."
                if is_english
                else "Je n'ai pas pu terminer l'analyse."
            )

        is_transfer_action = bool(action_detected == "prepare_transfer" and action_id)
        return {
            "response": final_response_text,
            "action": action_detected,
            "action_id": action_id,
            "action_data": action_data_detected,
            "sentiment": "positive",
            "suggestions": [],
            "provider": "VERTEX_AI_AGENT",
            "model": self.model,
            "requires_confirmation": is_transfer_action,
            "requires_biometric": is_transfer_action,
            "requires_security_validation": is_transfer_action,
            "status": "WAITING_CONFIRMATION" if is_transfer_action else "PROCESSED",
            "should_speak": True,
            "agent_steps": agent_steps,
            "language": "en" if is_english else "fr",
        }

# Instance globale utilisée dans l'application
sika_ai_service = SikaAIService()

# Compatibilité avec les anciens imports
SikaAI = SikaAIService