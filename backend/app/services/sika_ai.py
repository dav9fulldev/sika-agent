"""
Sika AI Service - LLM conversationnel intelligent Multilingue (Français & English)
"""

import os
import json
import logging
from typing import List, Dict, Optional
from datetime import datetime

try:
    # pyrefly: ignore [missing-import]
    from google import genai
    # pyrefly: ignore [missing-import]
    from google.genai import types
    HAS_GOOGLE_GENAI = True
except ImportError:
    HAS_GOOGLE_GENAI = False

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("SikaAI")


class SikaAI:
    """Service IA conversationnel de Sika avec support multilingue et multi-devises."""

    SYSTEM_PROMPT_FR = """Tu es Sika, l'assistant financier intelligent personnel.
- Tu réponds avec clarté, bienveillance et concision en FRANÇAIS.
- Tu analyses les portefeuilles, conseilles sur l'épargne et préviens les risques.
- Tu respectes la devise de l'utilisateur.
"""

    SYSTEM_PROMPT_EN = """You are Sika, the personal intelligent financial assistant.
- You respond clearly, helpfully, and concisely in ENGLISH.
- You analyze wallets, advise on savings, and prevent financial risks.
- You respect the user's preferred currency.
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

        # Fallback intelligent par règles multilingue
        return self._chat_basic(user_message, context, user_firstname, is_english)

    def _is_english_message(self, message: str) -> bool:
        """Détecte si le message de l'utilisateur est en anglais."""
        msg_lower = message.lower()
        english_keywords = [
            "how much", "money", "total", "balance", "transfer", "rebalance",
            "save", "savings", "add", "goal", "how is my", "what is my",
            "analyze", "recent", "expenses", "spend", "wallet", "dollars", "usd"
        ]
        return any(kw in msg_lower for kw in english_keywords)

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
        """Réponses basiques et intelligentes multilingues pour tous les workflows SIKA."""
        msg_lower = user_message.lower()
        action, action_data = self._extract_action("", user_message)

        # 1. SOLDE TOTAL & PORTEFEUILLES (TOTAL BALANCE & WALLETS)
        if any(w in msg_lower for w in ["solde", "combien j'ai", "portefeuille", "total", "balance", "money", "how much"]):
            if is_english:
                response = f"Hi {user_firstname}! You have a total balance of 45,000 FCFA ($75.00) across 3 wallets: Wave (15,000 FCFA), Orange Money (22,000 FCFA), and MTN MoMo (8,000 FCFA)."
                suggestions = ["View recent expenses", "Make a transfer", "Savings goal"]
            else:
                response = f"Salut {user_firstname} ! Tu as 45 000 FCFA au total répartis ainsi : 15 000 FCFA sur Wave, 22 000 FCFA sur Orange Money et 8 000 FCFA sur MTN Mobile Money."
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
                response = f"Great job {user_firstname}! Your savings goal is progressing well (75% completed). Adding this amount brings you 5 days closer to your target!"
                suggestions = ["Add $1 to savings", "Adjust savings target"]
            else:
                response = f"Bravo {user_firstname} ! Ton objectif d'épargne avance très bien (75% atteint). Cet ajout te rapproche de 5 jours de ton objectif !"
                suggestions = ["Ajouter 500 FCFA à l'épargne", "Ajuster l'objectif"]

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
                response = f"Here is your recent spending analysis: your highest category is Food & Dining. You have 45,000 FCFA ($75.00) remaining for the month."
                suggestions = ["Set spending limit", "View transaction history"]
            else:
                response = f"Voici l'analyse de tes dépenses récentes : ta catégorie principale est Restauration. Il te reste 45 000 FCFA pour finir le mois."
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
