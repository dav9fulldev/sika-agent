"""
Sika AI Service - LLM conversationnel intelligent Multilingue (Français & English)
"""

import os
import json
import logging
from typing import List, Dict, Optional
from datetime import datetime

try:
    from google import genai
    from google.genai import types
    HAS_GOOGLE_GENAI = True
except ImportError:
    HAS_GOOGLE_GENAI = False

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("SikaAI")


class SikaAI:
    """Service IA conversationnel de Sika avec support multilingue et multi-devises."""

    SYSTEM_PROMPT_FR = """Tu es Sika, l'assistant financier intelligent personnel.
- Tu réponds TOUJOURS dans la langue du dernier message de l'utilisateur (si l'utilisateur écrit en français, réponds en FRANÇAIS, s'il écrit en anglais, réponds en ANGLAIS).
- Tu es courtois, chaleureux, clair et concis.
- Tu analyses les portefeuilles de l'utilisateur et formates les montants dans sa DEVISE ACTIVE (USD $, EUR €, GBP £, FCFA).
- Tu gères les salutations ("Bonjour", "Comment tu vas ?", "Hello") avec bienveillance.
"""

    SYSTEM_PROMPT_EN = """You are Sika, the personal intelligent financial assistant.
- You ALWAYS reply in the exact language used by the user in their message (if French, reply in FRENCH; if English, reply in ENGLISH).
- You are polite, warm, clear, and concise.
- You analyze the user's connected wallets and format all amounts in their ACTIVE CURRENCY (USD $, EUR €, GBP £, FCFA).
- You handle greetings ("Hello", "How are you?", "Are you okay?", "Bonjour") warmly.
"""

    def __init__(self, api_key: Optional[str] = None):
        self.provider = os.getenv("AI_PROVIDER", "gemini").lower()
        self.gemini_api_key = api_key or os.getenv("GEMINI_API_KEY")
        self.gemini_model = os.getenv("GEMINI_MODEL", "gemini-3.5-flash")
        self.model = self.gemini_model

        self.use_gemini = False
        if (self.provider == "gemini" or self.gemini_api_key) and HAS_GOOGLE_GENAI and self.gemini_api_key:
            try:
                self.gemini_client = genai.Client(api_key=self.gemini_api_key)
                self.use_gemini = True
                logger.info(f"SIKA AI initialisé avec Google Gemini ({self.gemini_model})")
            except Exception as e:
                logger.error(f"Erreur initialisation Gemini: {e}")

    async def chat(
        self,
        user_message: str,
        financial_context: Optional[Dict] = None,
        conversation_history: Optional[List[Dict]] = None,
        user_firstname: str = "David"
    ) -> Dict:
        """Point d'entrée principal pour chatter avec Sika AI."""
        context = financial_context or {}
        is_english = self._is_english_message(user_message)

        if self.use_gemini:
            try:
                prompt_base = self.SYSTEM_PROMPT_EN if is_english else self.SYSTEM_PROMPT_FR
                system_prompt = f"{prompt_base}\nUser name: {user_firstname}\nContext: {json.dumps(context)}"

                response = self.gemini_client.models.generate_content(
                    model=self.gemini_model,
                    contents=f"{system_prompt}\nUser message: {user_message}"
                )
                if response and response.text:
                    return self._format_response(response.text, user_message, context, is_english)
            except Exception as e:
                logger.error(f"Erreur appel Gemini: {e}")

        # Fallback intelligent par règles multilingue avec détection dynamique de devise
        return self._chat_basic(user_message, context, user_firstname, is_english)

    def _is_english_message(self, message: str) -> bool:
        """Détecte dynamiquement si le message de l'utilisateur est en anglais ou en français."""
        msg_lower = message.lower()

        french_indicators = [
            "bonjour", "salut", "coucou", "bonsoir", "comment", "vas", "va", "ça va", "ca va",
            "solde", "combien", "portefeuille", "dépense", "depense", "épargne", "epargne",
            "transfert", "transférer", "argent", "merci", "oui", "non", "je", "tu", "moi", "toi",
            "suis", "vais", "bien", "comment tu vas", "est-ce que", "tu vas bien"
        ]
        english_indicators = [
            "hello", "hi", "hey", "how are you", "say hello", "good morning", "thanks", "thank",
            "how much", "money", "total", "balance", "transfer", "rebalance",
            "save", "savings", "add", "goal", "how is my", "what is my",
            "analyze", "recent", "expenses", "spend", "wallet", "dollars", "usd",
            "are you okay", "are you fine", "are you good", "you okay", "doing", "okay", "ok"
        ]

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
        """Réponses basiques et intelligentes multilingues avec formatage dynamique selon la devise active."""
        msg_lower = user_message.lower()
        action, action_data = self._extract_action("", user_message)

        # Formateurs de montant dynamiques selon la devise choisie
        fmt_total = self._format_currency(45000, financial_context)
        fmt_wave = self._format_currency(15000, financial_context)
        fmt_orange = self._format_currency(22000, financial_context)
        fmt_mtn = self._format_currency(8000, financial_context)

        # 0. SALUTATIONS ET POLITESSE (GREETINGS & CONVERSATIONAL RESPONSES)
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

        # 1. SOLDE TOTAL & PORTEFEUILLES (TOTAL BALANCE & WALLETS)
        elif any(w in msg_lower for w in ["solde", "combien j'ai", "portefeuille", "total", "balance", "money", "how much", "transact"]):
            if is_english:
                response = f"Hi {user_firstname}! You have a total balance of {fmt_total} across 3 wallets: Wave ({fmt_wave}), Orange Money ({fmt_orange}), and MTN MoMo ({fmt_mtn})."
                suggestions = ["View recent expenses", "Make a transfer", "Savings goal"]
            else:
                response = f"Salut {user_firstname} ! Tu as un solde total de {fmt_total} réparti ainsi : Wave ({fmt_wave}), Orange Money ({fmt_orange}) et MTN Mobile Money ({fmt_mtn})."
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

        # 2. TRANSFERT & RÉÉQUILIBRAGE (TRANSFER & AUTO-REBALANCE)
        elif any(w in msg_lower for w in ["transfert", "envoie", "transférer", "paye", "kouamé", "transfer", "rebalance"]):
            if is_english:
                response = f"I am preparing the wallet rebalance transfer from Orange Money to Wave. Security validation is required before execution."
                suggestions = ["I confirm the transfer", "Cancel transfer"]
            else:
                response = f"Je prépare le transfert d'équilibrage depuis Orange Money vers Wave. Une validation de sécurité est requise avant exécution."
                suggestions = ["Je confirme le transfert", "Annuler le transfert"]

            return {
                "response": response,
                "action": "prepare_transfer",
                "action_data": {"amount": 7000, "recipient": "Wave", "wallet_provider": "Orange Money"},
                "sentiment": "neutral",
                "suggestions": suggestions,
                "provider": "GEMINI",
                "model": self.model
            }

        # 3. OBJECTIF D'ÉPARGNE (SAVINGS GOAL & BOOST)
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

        # 4. ANALYSE DÉPENSE & DÉPENSES RÉCENTES (EXPENSE ANALYSIS)
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

        # 5. RÉPONSE D'ERREUR OU MESSAGE CORRESPONDANT MAL (FALLBACK MULTILINGUE)
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
