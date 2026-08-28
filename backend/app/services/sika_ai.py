import os
import re
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

    def _is_english(self, message: str) -> bool:
        """Détection simple de la langue anglaise."""

        msg_lower = message.lower()

        french_indicators = [
            "solde",
            "dépense",
            "dépensé",
            "combien",
            "épargne",
            "bonjour",
            "salut",
            "transfert",
            "transférer",
            "mon",
            "ma",
            "mes",
            "coffre",
            "budget",
        ]

        english_indicators = [
            "balance",
            "spending",
            "spent",
            "how much",
            "savings",
            "hello",
            "hi",
            "transfer",
            "wallet",
            "safe",
            "budget",
            "expenses",
        ]

        fr_count = sum(
            1 for keyword in french_indicators
            if keyword in msg_lower
        )

        en_count = sum(
            1 for keyword in english_indicators
            if keyword in msg_lower
        )

        if en_count > fr_count:
            return True

        return False

    def _format_currency(
        self,
        amount_fcfa: float,
        context: Dict[str, Any]
    ) -> str:
        """
        Formate un montant selon la devise active.

        Les montants internes de SIKA sont actuellement
        exprimés en FCFA.
        """

        code = (
            context.get("currency_code")
            or "XOF"
        ).upper()

        symbol = (
            context.get("currency_symbol")
            or "FCFA"
        )

        if code == "USD" or symbol == "$":
            value = amount_fcfa / 600.0
            return f"${value:.2f}"

        elif code == "EUR" or symbol == "€":
            value = amount_fcfa / 655.957
            return f"{value:.2f} €"

        elif code == "GBP" or symbol == "£":
            value = amount_fcfa / 770.0
            return f"£{value:.2f}"

        return f"{int(amount_fcfa):,} FCFA".replace(",", " ")

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
                {
                    "amount": 10000.0,
                    "recipient": "Kouamé",
                    "provider": "Wave",
                },
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

    def _chat_basic(
        self,
        user_message: str,
        financial_context: Dict[str, Any],
        user_firstname: str,
        is_english: bool,
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

            else:

                wallet_details = []

                for wallet in active_wallets:

                    formatted_balance = self._format_currency(
                        wallet.get("balance", 0.0),
                        financial_context,
                    )

                    provider_name = wallet.get(
                        "provider",
                        "Wallet"
                    )

                    account_number = wallet.get(
                        "account_number",
                        ""
                    )

                    account_info = (
                        f" ({account_number})"
                        if account_number
                        else ""
                    )

                    wallet_details.append(
                        f"{provider_name}{account_info} : "
                        f"{formatted_balance}"
                    )

                details_str = ", ".join(
                    wallet_details
                )

                if is_english:

                    response = (
                        f"Hi {user_firstname}! "
                        f"You have a total balance of "
                        f"{fmt_total} across "
                        f"{len(active_wallets)} connected wallet(s): "
                        f"{details_str}."
                    )

                    suggestions = [
                        "View recent expenses",
                        "Make a transfer",
                        "Savings goal",
                    ]

                else:

                    response = (
                        f"Salut {user_firstname} ! "
                        f"Tu as un solde total de "
                        f"**{fmt_total}** réparti ainsi : "
                        f"{details_str}."
                    )

                    suggestions = [
                        "Voir mes dépenses récentes",
                        "Effectuer un transfert",
                        "Objectif d'épargne",
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
                    "Deposit 10 000 FCFA into safe",
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
                    "Déposer 10 000 FCFA dans le coffre",
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
                "action_data": None,
                "sentiment": "positive",
                "suggestions": suggestions,
                "provider": "VERTEX_AI",
                "model": self.model,
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

            if is_english:

                response = (
                    "I am preparing the wallet rebalance transfer. "
                    "Security confirmation is required "
                    "before execution."
                )

                suggestions = [
                    "I confirm the transfer",
                    "Cancel transfer",
                ]

            else:

                response = (
                    "Je prépare le transfert d'équilibrage. "
                    "Une validation de sécurité est requise "
                    "avant son exécution."
                )

                suggestions = [
                    "Je confirme le transfert",
                    "Annuler le transfert",
                ]

            return {
                "response": response,
                "action": "prepare_transfer",
                "action_data": {
                    "amount": 7000,
                    "recipient": "Wave",
                    "wallet_provider": "PayMeChap",
                },
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
                        "setting aside between 10 000 FCFA "
                        "and 15 000 FCFA could be a good option. "
                        "Would you like me to prepare the deposit?"
                    )

                    suggestions = [
                        "Deposit 10 000 FCFA into safe",
                        "Deposit 15 000 FCFA into safe",
                        "Check total balance",
                    ]

                else:

                    response = (
                        f"En tenant compte de ton contexte financier "
                        f"{user_firstname}, mettre de côté entre "
                        "10 000 FCFA et 15 000 FCFA pourrait être "
                        "une bonne option. "
                        "Souhaites-tu que je prépare le dépôt ?"
                    )

                    suggestions = [
                        "Déposer 10 000 FCFA dans le coffre",
                        "Déposer 15 000 FCFA dans le coffre",
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

        action, action_data = self._extract_action(
            sika_response,
            user_message,
        )

        return {
            "response": sika_response,
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

        if not self.client:
            return self._chat_basic(user_message, context, firstname, is_english)

        from ..agent.tool_registry import tool_registry
        from google.genai import types

        safe_tools = tool_registry.get_gemini_tools()

        active_wallets = [w for w in context.get("wallets", []) if w.get("is_active", True)]
        total_balance_fcfa = sum(w.get("balance", 0.0) for w in active_wallets)
        
        context_str = f"Solde total: {total_balance_fcfa} FCFA\nComptes: " + ", ".join([f"{w.get('provider', 'Compte')} ({w.get('balance', 0.0)} FCFA)" for w in active_wallets])

        system_instruction = f"""
Tu es SIKA, un agent financier intelligent pour PayMeChap.
Utilisateur : {firstname}

Contexte financier de l'utilisateur :
{context_str}

RÈGLES STRICTES :
1. Tu dois aider l'utilisateur à comprendre ses finances, épargner, et transférer de l'argent.
2. N'invente JAMAIS un solde ou une transaction. Utilise les outils disponibles pour chercher l'information.
3. Si l'utilisateur veut envoyer de l'argent, utilise `search_contact` pour vérifier le numéro, puis appelle `prepare_transfer`.
4. Si une information est ambiguë (plusieurs contacts avec le même nom), pose une question courte pour clarifier avant d'agir. Ne demande PAS le numéro si tu l'as déjà trouvé.
5. Tu ne peux pas exécuter directement une transaction. Appelle `prepare_transfer`, cela mettra la transaction en attente de confirmation humaine.
6. Réponds de manière concise, naturelle et chaleureuse.
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
                return self._chat_basic(user_message, context, firstname, is_english)

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
                            final_response_text = f"J'ai préparé l'opération. Veux-tu confirmer ?"
                        break
                
                if action_detected == "prepare_transfer":
                    break
            else:
                # No function calls, so it's a final text response
                final_response_text = response.text
                break
                
            step += 1
            
        if not final_response_text:
            final_response_text = "Je n'ai pas pu terminer l'analyse."

        return {
            "response": final_response_text,
            "action": action_detected,
            "action_id": action_id,
            "action_data": action_data_detected,
            "sentiment": "positive",
            "suggestions": [],
            "provider": "VERTEX_AI_AGENT",
            "model": self.model,
            "requires_confirmation": (action_detected == "prepare_transfer"),
            "status": "WAITING_CONFIRMATION" if action_detected == "prepare_transfer" else "PROCESSED",
            "should_speak": True,
            "agent_steps": agent_steps,
        }

# Instance globale utilisée dans l'application
sika_ai_service = SikaAIService()

# Compatibilité avec les anciens imports
SikaAI = SikaAIService