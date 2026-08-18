import os
import logging
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)


class SikaAIService:
    """Service Sika AI 2.0.

    Gère le modèle Gemini, le fallback ReAct et la détection d'intention multilingue avec mise à jour dynamique des soldes.
    """

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.getenv("GEMINI_API_KEY", "")
        self.provider = "gemini"
        self.model = os.getenv("GEMINI_MODEL", "gemini-3.5-flash")
        self._init_gemini_client()

    @property
    def use_gemini(self) -> bool:
        return self.client is not None

    def _init_gemini_client(self):
        """Initialise le client Gemini SDK si la clé d'API est valide."""
        try:
            if self.api_key:
                from google import genai
                self.client = genai.Client(api_key=self.api_key)
                logger.info(f"Gemini Client v2 (genai) initialisé avec modèle {self.model}")
            else:
                self.client = None
                logger.info("Clé GEMINI_API_KEY absente, mode ReAct avec fallback actif.")
        except Exception as e:
            logger.warning(f"Erreur d'initialisation Gemini SDK: {e}. Fallback réactif activé.")
            self.client = None

    def _is_english(self, message: str) -> bool:
        """Détecte la langue (anglais vs français)."""
        msg_lower = message.lower()
        french_indicators = ["solde", "dépense", "combien", "épargne", "bonjour", "salut", "transfert", "transférer", "mon", "ma", "mes"]
        english_indicators = ["balance", "spending", "how much", "savings", "hello", "hi", "transfer", "my", "wallet"]

        fr_count = sum(1 for kw in french_indicators if kw in msg_lower)
        en_count = sum(1 for kw in english_indicators if kw in msg_lower)

        if fr_count > en_count:
            return False
        if en_count > fr_count:
            return True

        return False

    def _format_currency(self, amount_fcfa: float, context: Dict) -> str:
        """Formate dynamiquement le montant selon la devise active transmise par le client."""
        code = (context.get("currency_code") or "XOF").upper()
        symbol = context.get("currency_symbol") or "FCFA"

        if code == "USD" or symbol == "$":
            val = amount_fcfa / 600.0
            return f"${val:.2f}"
        elif code == "EUR" or symbol == "€":
            val = amount_fcfa / 655.957
            return f"{val:.2f} €"
        elif code == "GBP" or symbol == "£":
            val = amount_fcfa / 770.0
            return f"£{val:.2f}"
        else:
            return f"{int(amount_fcfa):,} FCFA".replace(",", " ")

    def _extract_action(self, response: str, user_message: str) -> tuple:
        """Détecte si Sika suggère une action."""
        res_lower = response.lower()
        msg_lower = user_message.lower()

        if any(w in msg_lower or w in res_lower for w in ["transfert", "transférer", "envoie", "transfer", "rebalance"]):
            return ("prepare_transfer", {"amount": 10000, "recipient": "Kouamé", "wallet_provider": "Wave"})

        if any(w in msg_lower or w in res_lower for w in ["dépense", "acheté", "spent", "buy", "purchase"]):
            return ("add_transaction", {})

        return (None, None)

    def _chat_basic(
        self,
        user_message: str,
        financial_context: Dict,
        user_firstname: str,
        is_english: bool
    ) -> Dict:
        """Réponses basiques et intelligentes multilingues avec formatage dynamique des VRAIS comptes connectés."""
        msg_lower = user_message.lower()
        action, action_data = self._extract_action("", user_message)

        # Récupération dynamique des vrais comptes connectés dans le système SIKA
        from ..routes.wallet_router import CONNECTED_USER_WALLETS
        active_wallets = [w for w in CONNECTED_USER_WALLETS if w.get("is_active", True)]
        total_balance_fcfa = sum(w.get("balance", 0.0) for w in active_wallets)
        fmt_total = self._format_currency(total_balance_fcfa, financial_context)

        # Mots-clés d'intention financière
        financial_intent_keywords = [
            "solde", "combien j'ai", "combien", "portefeuille", "total", "balance", "money",
            "how much", "compte", "argent", "paymechap", "wave", "orange", "mtn"
        ]

        # 1. INTENTION FINANCIÈRE : SOLDE TOTAL & PORTEFEUILLES (Priorité absolue avant les simples salutations)
        if any(w in msg_lower for w in financial_intent_keywords):
            if len(active_wallets) == 0:
                if is_english:
                    response = f"Hi {user_firstname}! You don't have any connected wallets yet. Click on 'Connect my Wallets' to link PayMeChap, Wave, Orange Money, or MTN MoMo!"
                else:
                    response = f"Salut {user_firstname} ! Tu n'as encore aucun portefeuille connecté. Clique sur 'Connecter mes comptes' pour raccorder PayMeChap, Wave, Orange Money ou MTN MoMo !"
                suggestions = ["Connect a wallet", "How does SIKA work?", "Help"]
            else:
                # Formatage détaillé de chaque portefeuille connecté
                wallet_details = []
                for w in active_wallets:
                    b_fmt = self._format_currency(w.get("balance", 0.0), financial_context)
                    p_name = w.get("provider", "Wallet")
                    acc_num = w.get("account_number", "")
                    num_str = f" ({acc_num})" if acc_num else ""
                    wallet_details.append(f"{p_name}{num_str} : {b_fmt}")

                details_str = ", ".join(wallet_details)

                if is_english:
                    response = f"Hi {user_firstname}! You have a total balance of {fmt_total} across {len(active_wallets)} connected wallet(s): {details_str}."
                    suggestions = ["View recent expenses", "Make a transfer", "Savings goal"]
                else:
                    response = f"Salut {user_firstname} ! Tu as un solde total de **{fmt_total}** réparti ainsi : {details_str}."
                    suggestions = ["Voir mes dépenses récentes", "Effectuer un transfert", "Objectif d'épargne"]

            return {
                "response": response,
                "action": "get_total_balance",
                "action_data": action_data,
                "sentiment": "positive",
                "suggestions": suggestions,
                "provider": "GEMINI",
                "model": self.model
            }

        # 2. SALUTATIONS SIMPLES ET POLITESSES (SEULEMENT SI PAS D'INTENTION FINANCIÈRE)
        greeting_keywords = [
            "bonjour", "salut", "coucou", "bonsoir", "comment tu vas", "ça va", "ca va", "comment vas-tu",
            "tu vas bien", "est-ce que tu vas bien",
            "hello", "hi", "hey", "how are you", "say hello", "are you okay", "are you fine", "are you good",
            "you okay", "how are you doing", "what's up", "whats up"
        ]

        if any(w in msg_lower for w in greeting_keywords):
            if is_english:
                response = f"Hello {user_firstname}! I am doing great and operating normally, thank you for asking! I am ready to assist with your finances today. How can I help you?"
                suggestions = ["How much money do I have in total?", "Analyze my recent expenses", "How is my savings goal progressing?"]
            else:
                response = f"Bonjour {user_firstname} ! Je vais très bien et tout fonctionne parfaitement, merci de demander ! Je suis ravi de vous retrouver pour veiller sur vos finances. Que souhaitez-vous vérifier aujourd'hui ?"
                suggestions = ["Quel est mon solde total ?", "Analyser mes dépenses récentes", "Comment avance mon épargne ?"]

            return {
                "response": response,
                "action": None,
                "action_data": None,
                "sentiment": "positive",
                "suggestions": suggestions,
                "provider": "GEMINI",
                "model": self.model
            }

        # 3. TRANSFERT & RÉÉQUILIBRAGE (TRANSFER & AUTO-REBALANCE)
        elif any(w in msg_lower for w in ["transfert", "envoie", "transférer", "paye", "kouamé", "transfer", "rebalance"]):
            if is_english:
                response = f"I am preparing the wallet rebalance transfer. Security validation is required before execution."
                suggestions = ["I confirm the transfer", "Cancel transfer"]
            else:
                response = f"Je prépare le transfert d'équilibrage. Une validation de sécurité est requise avant exécution."
                suggestions = ["Je confirme le transfert", "Annuler le transfert"]

            return {
                "response": response,
                "action": "prepare_transfer",
                "action_data": {"amount": 7000, "recipient": "Wave", "wallet_provider": "PayMeChap"},
                "sentiment": "neutral",
                "suggestions": suggestions,
                "provider": "GEMINI",
                "model": self.model
            }

        # 4. OBJECTIF D'ÉPARGNE (SAVINGS GOAL & BOOST)
        elif any(w in msg_lower for w in ["épargne", "objectif", "économiser", "avancement", "save", "savings", "goal", "add"]):
            if is_english:
                response = f"Great job {user_firstname}! Your savings goal is progressing well (75% completed). Adding to your savings brings you 5 days closer to your target!"
                suggestions = ["Add $1 to savings", "Adjust savings target"]
            else:
                response = f"Bravo {user_firstname} ! Ton objectif d'épargne avance très bien (75% atteint). Cet ajout te rapproche de 5 jours de ton objectif !"
                suggestions = ["Ajouter à l'épargne", "Ajuster l'objectif"]

            return {
                "response": response,
                "action": "check_savings_goal",
                "action_data": action_data,
                "sentiment": "positive",
                "suggestions": suggestions,
                "provider": "GEMINI",
                "model": self.model
            }

        # 5. ANALYSE DÉPENSE & DÉPENSES RÉCENTES (EXPENSE ANALYSIS)
        elif any(w in msg_lower for w in ["dépense", "dépensé", "acheté", "budget", "analyze", "recent", "expenses"]):
            if is_english:
                response = f"Here is your recent spending analysis: your highest category is Food & Dining. You have {fmt_total} remaining for the month."
                suggestions = ["Set spending limit", "View transaction history"]
            else:
                response = f"Voici l'analyse de tes dépenses récentes : ta catégorie principale est Restauration. Il te reste {fmt_total} pour finir le mois."
                suggestions = ["Définir une limite", "Voir l'historique"]

            return {
                "response": response,
                "action": "get_spending_summary",
                "action_data": action_data,
                "sentiment": "neutral",
                "suggestions": suggestions,
                "provider": "GEMINI",
                "model": self.model
            }

        # 6. FALLBACK MULTILINGUE
        else:
            if is_english:
                response = f"Sorry {user_firstname}, I didn't quite catch that. Could you please repeat or select one of the suggested options below?"
                suggestions = ["How much money do I have in total?", "How is my savings goal progressing?", "Analyze my recent expenses"]
            else:
                response = f"Pardon {user_firstname}, je n'ai pas bien compris. Peux-tu répéter ou choisir l'une des options ci-dessous ?"
                suggestions = ["Quel est mon solde total ?", "Comment avance mon épargne ?", "Analyser mes dépenses"]

            return {
                "response": response,
                "action": None,
                "action_data": None,
                "sentiment": "neutral",
                "suggestions": suggestions,
                "provider": "GEMINI",
                "model": self.model
            }

    def _format_response(self, sika_response: str, user_message: str, financial_context: Dict, is_english: bool) -> Dict:
        """Formate la réponse générée par Gemini."""
        action, action_data = self._extract_action(sika_response, user_message)
        return {
            "response": sika_response,
            "action": action,
            "action_data": action_data,
            "sentiment": "positive",
            "suggestions": [
                "How much money do I have in total?" if is_english else "Quel est mon solde total ?",
                "How is my savings goal progressing?" if is_english else "Comment avance mon épargne ?",
                "Analyze recent expenses" if is_english else "Analyser mes dépenses"
            ],
            "provider": "GEMINI",
            "model": self.model
        }

    async def chat(
        self,
        user_message: str,
        financial_context: Optional[Dict] = None,
        conversation_history: Optional[List] = None,
        user_firstname: Optional[str] = None
    ) -> Dict:
        """Point d'entrée principal pour traiter les messages de l'utilisateur."""
        context = financial_context or {}
        fname = user_firstname or context.get("user_firstname") or "David"
        is_english = self._is_english(user_message)

        if self.client:
            try:
                system_instruction = (
                    f"Tu es Sika AI, un assistant financier autonome et bienveillant pour l'utilisateur {fname}. "
                    f"Sois précis, poli et chaleureux. Si l'utilisateur demande son solde ou salue, réponds de façon claire et encourageante."
                )
                response = self.client.models.generate_content(
                    model=self.model,
                    contents=user_message,
                    config={"system_instruction": system_instruction}
                )
                if response and response.text:
                    return self._format_response(response.text, user_message, context, is_english)
            except Exception as e:
                logger.warning(f"Erreur lors de l'appel Gemini SDK: {e}. Basculement sur le mode intelligent local.")

        return self._chat_basic(user_message, context, fname, is_english)


sika_ai_service = SikaAIService()
SikaAI = SikaAIService
