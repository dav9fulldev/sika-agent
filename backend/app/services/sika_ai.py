import os
import re
import json
import logging
from typing import Dict, Any, Optional, List, Tuple

from google import genai

logger = logging.getLogger(__name__)


class SikaAIService:
    """
    Service IA principal de SIKA Pay.

    Architecture :
    - Gemini via Vertex AI (ADC) ou via une clé Gemini Developer API (GEMINI_API_KEY)
    - Function Calling vers les tools SIKA Pay (catalogue, préparation de checkout PayPal, statut)
    - Repli déterministe local si Gemini est indisponible (jamais de résultat PayPal simulé)
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
            api_key = os.getenv("GEMINI_API_KEY")
            if api_key:
                # Alternative reviewers : clé Gemini Developer API (Google AI Studio), sans projet GCP
                self.client = genai.Client(api_key=api_key)
                self.provider = "gemini_api"
                logger.info(f"🤖 SIKA connecté à Gemini Developer API | model={self.model}")
                return

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
        Priorité naturelle au Français (zone UEMOA / Afrique de l'Ouest).
        """
        if not message or not message.strip():
            return "fr"

        msg_lower = message.lower().strip()

        # Expressions et motifs forts anglais
        en_phrases = [
            "what's my", "what is my", "whats my", "how much", "how's my", "how is my",
            "my balance", "total balance", "recent spending", "recent expenses",
            "send ", "transfer ", "check my", "show me", "can you", "please ",
            "what can you do", "who are you", "how are you", "good morning", "good evening"
        ]
        # Expressions et motifs forts français
        fr_phrases = [
            "quel est", "quelle est", "quels sont", "quelles sont", "combien j'ai",
            "combien de", "combien sur", "mon solde", "solde total", "mes dépenses",
            "mes depenses", "dépenses récentes", "envoie ", "envoyer ", "transférer ",
            "fais un", "fait un", "fais le", "fait le", "s'il te plaît", "sil te plait",
            "s'il vous plaît", "sil vous plait", "que peux-tu faire", "qui es-tu",
            "comment vas-tu", "comment tu vas", "bonjour", "salut", "stp", "svp"
        ]

        en_score = sum(4 for p in en_phrases if p in msg_lower)
        fr_score = sum(4 for p in fr_phrases if p in msg_lower)

        # Mots-clés individuels
        english_words = {
            "what", "what's", "whats", "how", "much", "is", "my", "total", "balance",
            "check", "spending", "spent", "expenses", "expense", "send", "transfer",
            "savings", "safe", "deposit", "withdraw", "hello", "hi", "hey", "please",
            "can", "you", "show", "recent", "analyze", "analysis", "money", "wallet",
            "wallets", "account", "accounts", "thanks", "thank",
            # SIKA Pay (commerce)
            "i", "want", "buy", "purchase", "order", "help", "need", "the", "to", "for", "under",
            "dollar", "dollars", "course", "pay", "payment", "did", "through", "without", "over", "cheaper"
        }

        french_words = {
            "quel", "quelle", "quels", "quelles", "est", "sont", "mon", "ma", "mes",
            "solde", "soldes", "combien", "dépense", "dépenses", "dépensé", "depense",
            "depenses", "envoie", "envoyer", "transférer", "transferer", "transfert",
            "épargne", "epargne", "coffre", "coffres", "bonjour", "salut", "bonsoir",
            "coucou", "retrait", "retirer", "verser", "compte", "comptes", "portefeuille",
            "portefeuilles", "analyse", "analyser", "récent", "recents", "récentes", "recentes",
            "merci", "argent", "fonds", "fais", "fait", "effectue", "rapide", "vite",
            "stp", "svp", "franc", "francs", "cfa", "fcfa", "xof", "un", "une", "des",
            "du", "au", "aux", "sur", "vers", "pour", "avec", "de", "le", "la", "les",
            # SIKA Pay (commerce)
            "je", "veux", "acheter", "achète", "achete", "aide", "aide-moi", "cours", "moins", "paiement",
            "commander", "payer", "dépasser", "depasser", "sans"
        }

        tokens = set(re.findall(r"\b[a-zA-Z'’àâäéèêëîïôöùûüç]+\b", msg_lower))
        en_score += sum(1 for t in tokens if t in english_words)
        fr_score += sum(1 for t in tokens if t in french_words)

        if fr_score >= en_score and fr_score > 0:
            return "fr"
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

    # ==================================================================
    # SIKA Pay — Agent de commerce PayPal (sandbox)
    # ==================================================================

    @staticmethod
    def _confirmation_rule(mandate: Optional[Dict[str, Any]]) -> str:
        if not mandate or not mandate.get("active"):
            return ("The user must review the confirmation card in the app, confirm, then approve on PayPal; the payment is "
                    "captured after the PayPal approval. You cannot confirm, approve or capture a payment yourself.")
        return (f"The user AUTHORIZED you to confirm purchases on their behalf: up to {mandate['max_per_purchase']} "
                f"{mandate['currency']} per purchase and {mandate['daily_limit']} {mandate['currency']} per day "
                f"({mandate['remaining_today']} left today), until {mandate['expires_at']}. When the user clearly asks you to BUY "
                "(not just to find, compare or check a price), call `confirm_checkout_with_authorization(checkout_id)` right after "
                "a successful `prepare_paypal_checkout`. The backend enforces the limits: if it refuses, explain why and tell the "
                "user to confirm in the app. The user still approves the order on PayPal; you never approve or capture yourself. "
                "Say clearly when you confirmed on their behalf.")

    def _sika_pay_instruction(self, firstname: str, lang_instruction: str, mandate: Optional[Dict[str, Any]] = None) -> str:
        confirmation_rule = self._confirmation_rule(mandate)
        return f"""
You are SIKA Pay, a personal AI payment agent. You help {firstname} make informed, controlled purchases
with PayPal (SANDBOX test environment — no real money moves).

You can shop in two places:
- PARTNER STORE "SIKA Demo Store" (fictional demo catalog, USD): purchases are paid INSIDE the app with PayPal
  (tools `search_demo_catalog`, `prepare_paypal_checkout`). Use it by default for "buy" requests that match its catalog.
- THE WEB: `search_web_products` finds REAL products at real online merchants and compares their offers. SIKA cannot pay
  there: the user opens the merchant page from the card and pays on the merchant's site (with PayPal when offered).
  Use it when the user asks to search, compare or find the best price online, names a real brand or website, or when the
  partner store has nothing that fits. Never claim you can buy or pay on those sites, and never invent a merchant or price.
  The tool returns exactly the products shown as cards (at most 3): mention only those, in the same order, with their best
  price and merchant, and say how many products and merchants you compared (`products_compared`, `merchants_compared`).
  Plain text only: no markdown, no bold, no lists with symbols.

HOW YOU WORK:
1. Understand what the user wants to buy, their budget and the quantity.
2. ALWAYS call `search_demo_catalog` before suggesting or preparing a purchase. Never invent a product, SKU or price.
3. If several products match and the user's choice is unclear, list at most 3 options (name, price) and ask which one.
   If one product clearly matches the request, go ahead.
4. If an essential parameter is ambiguous (which product, quantity, budget currency), ask ONE short question instead of guessing.
5. To prepare the purchase, call `prepare_paypal_checkout(sku, quantity, budget_limit, budget_currency)`.
   - `sku` must come from a search result. `budget_limit` only if the user stated a budget. Use quantity 1 if unspecified.
   - You never pass an amount: the backend computes the price and checks the budget.
   - If it fails (for example OVER_BUDGET), explain why and propose the alternatives it returned. Do not retry with another product
     unless the user asks.
6. Preparing a checkout does NOT create a PayPal order and charges nothing. {confirmation_rule}
7. To answer "did my payment go through?" call `get_paypal_checkout_status` or `list_recent_paypal_checkouts` and report ONLY the
   statuses they return. "Order created", "approved" and "captured/completed" are different states: never merge them.
8. Separate clearly: what is verified (catalog price, backend total, PayPal statuses), what the user said (budget, quantity),
   and your assumptions.
9. SIKA never converts currencies. If the budget is not in USD, ask the user for a USD budget.
10. SIKA Pay only pays with PayPal (sandbox). Do not offer any other payment provider.
11. Be concise and warm: 2 to 5 short sentences, no markdown tables.

LANGUAGE: {lang_instruction}
"""

    def _checkout_summary_text(self, checkout: Dict[str, Any], is_english: bool) -> str:
        item = (checkout.get("item") or {}).get("name", "")
        total = f"{checkout.get('total_amount')} {checkout.get('currency')}"
        budget = checkout.get("budget") or {}
        agent_confirmed = checkout.get("status") == "AWAITING_PAYPAL_APPROVAL"
        if is_english:
            budget_txt = (
                f" It fits your budget of {budget.get('limit')} {budget.get('currency')} "
                f"({budget.get('remaining_after_purchase')} left)." if budget.get("limit") else ""
            )
            if agent_confirmed:
                return (f"I confirmed {checkout.get('quantity')} × {item} ({total}) on your behalf, within the authorization you "
                        f"gave me.{budget_txt} The PayPal sandbox order is created: nothing is charged until you approve it on "
                        "PayPal with the button on the card.")
            return (f"I prepared a PayPal sandbox checkout for {checkout.get('quantity')} × {item}: {total}, price taken from the "
                    f"demo store catalog.{budget_txt} Nothing has been charged and no PayPal order exists yet. "
                    "Tap \"Review summary\" on the card to confirm.")
        budget_txt = (
            f" C'est dans votre budget de {budget.get('limit')} {budget.get('currency')} "
            f"(reste {budget.get('remaining_after_purchase')})." if budget.get("limit") else ""
        )
        if agent_confirmed:
            return (f"J'ai confirmé pour vous {checkout.get('quantity')} × {item} ({total}), dans les limites de l'autorisation "
                    f"que vous m'avez donnée.{budget_txt} La commande PayPal sandbox est créée : rien n'est débité tant que vous "
                    "ne l'approuvez pas sur PayPal avec le bouton de la carte.")
        return (f"J'ai préparé un paiement PayPal sandbox pour {checkout.get('quantity')} × {item} : {total}, prix issu du "
                f"catalogue de démonstration.{budget_txt} Rien n'a été débité et aucune commande PayPal n'existe encore. "
                "Touchez « Voir le récapitulatif » sur la carte pour confirmer.")

    async def _explain_prepared_checkout(self, messages: list, system_instruction: str, checkout: Dict[str, Any],
                                         is_english: bool) -> str:
        """Laisse Gemini expliquer le checkout préparé (sans aucun tool disponible), avec repli déterministe."""
        fallback = self._checkout_summary_text(checkout or {}, is_english)
        if not self.client or not checkout:
            return fallback
        from google.genai import types
        try:
            response = await self.client.aio.models.generate_content(
                model=self.model,
                contents=messages,
                config=types.GenerateContentConfig(
                    system_instruction=system_instruction + (
                        "\nYou confirmed this purchase on the user's behalf under their authorization and the PayPal sandbox "
                        "order now exists. Explain it in 2-4 short sentences: item, total and currency, the budget check, and "
                        "that you confirmed it within their authorization. Say that nothing is charged until they approve "
                        "the order on PayPal (button \"Approve on PayPal\" on the card). Do not call any tool."
                        if checkout.get("status") == "AWAITING_PAYPAL_APPROVAL" else
                        "\nThe checkout is now prepared. Explain it in 2-4 short sentences: item, total and currency, "
                        "the budget check result. Mention which facts are verified and which come from the user. "
                        "Say clearly that nothing has been charged and no PayPal order exists yet, and that the user "
                        "must open the summary on the card (button \"Review summary\") and confirm there. Do not call any tool."
                    ),
                    temperature=0.2,
                ),
            )
            text = (response.text or "").strip()
            return text or fallback
        except Exception as e:
            logger.warning(f"[SIKA PAY] Explanation generation failed, deterministic summary used: {e}")
            return fallback

    def _chat_sika_pay_fallback(self, user_message: str, firstname: str, is_english: bool,
                                user_id: Optional[str], greeting: bool = False) -> Dict[str, Any]:
        """Moteur local déterministe SIKA Pay (sans LLM). Il ne simule jamais PayPal : il prépare au plus un checkout."""
        from decimal import Decimal
        from . import demo_catalog
        from ..agent.tool_registry import tool_registry

        def reply(text: str, action: str = "chat", action_id=None, action_data=None, steps=None) -> Dict[str, Any]:
            prepared = bool(action == "prepare_paypal_checkout" and action_id)
            return {
                "response": text,
                "action": action,
                "action_id": action_id,
                "action_data": action_data,
                "sentiment": "positive",
                "suggestions": [],
                "provider": "SIKA_LOCAL_FALLBACK",
                "model": "deterministic-rules",
                "requires_confirmation": prepared,
                "requires_biometric": prepared,
                "requires_security_validation": prepared,
                "status": "WAITING_CONFIRMATION" if prepared else "PROCESSED",
                "should_speak": True,
                "agent_steps": steps or [],
                "language": "en" if is_english else "fr",
            }

        if greeting:
            return reply(
                f"Hi {firstname}! I'm SIKA Pay. Tell me what you want to buy and your budget — for example "
                "\"Help me buy an Excel course under $50\" — and I'll prepare a PayPal sandbox checkout for you to approve."
                if is_english else
                f"Bonjour {firstname} ! Je suis SIKA Pay. Dites-moi ce que vous voulez acheter et votre budget — par exemple "
                "« Aide-moi à acheter un cours Excel à moins de 50 dollars » — et je prépare un paiement PayPal sandbox à approuver."
            )

        msg = user_message.lower()
        uid = str(user_id) if user_id else None

        if any(k in msg for k in ["status", "statut", "went through", "did my payment", "mon paiement", "history", "historique"]):
            res = tool_registry.execute("list_recent_paypal_checkouts", {"limit": 3, "user_id": uid})
            rows = res.data.get("checkouts", []) if res.success else []
            steps = [{"id": "step_1", "type": "list_recent_paypal_checkouts", "label": "Reading your SIKA Pay history", "status": "completed"}]
            if not rows:
                return reply("You have no SIKA Pay checkout yet." if is_english else "Vous n'avez encore aucun paiement SIKA Pay.", steps=steps)
            last = rows[0]
            return reply(
                f"Your latest checkout ({last['item']}, {last['total_amount']} {last['currency']}) is: {last['status_label']}."
                if is_english else
                f"Votre dernier paiement ({last['item']}, {last['total_amount']} {last['currency']}) : {last['status_label']}.",
                steps=steps,
            )

        purchase_words = ["buy", "purchase", "order", "pay for", "acheter", "achète", "achete", "commander", "payer", "paye"]
        if not any(k in msg for k in purchase_words):
            return reply(
                "My AI reasoning engine is unavailable right now, but I can still prepare a PayPal sandbox purchase from the "
                "demo store. Tell me what to buy and your budget."
                if is_english else
                "Mon moteur de raisonnement IA est indisponible pour le moment, mais je peux préparer un achat PayPal sandbox "
                "dans la boutique de démonstration. Dites-moi quoi acheter et votre budget."
            )

        budget = None
        m = re.search(r"(?:under|below|less than|max(?:imum)?|budget(?: of)?|moins de|pas plus de|maximum|budget de)\s*\$?\s*(\d+(?:[.,]\d{1,2})?)", msg) \
            or re.search(r"\$\s*(\d+(?:[.,]\d{1,2})?)|(\d+(?:[.,]\d{1,2})?)\s*(?:\$|usd|dollars?)", msg)
        if m:
            raw = next(g for g in m.groups() if g)
            budget = Decimal(raw.replace(",", "."))

        steps = [{"id": "step_1", "type": "search_demo_catalog", "label": "Searching the demo store catalog", "status": "completed"}]
        n_tokens = max(len(demo_catalog.query_tokens(user_message)), 1)
        # Correspondances fortes uniquement (au moins la moitié des mots-clés), budget appliqué ensuite par le backend
        ranked = [(s, p) for s, p in demo_catalog.rank_products(user_message, max_price=None, limit=5) if s * 3 >= n_tokens]
        if not ranked:
            return reply(
                "I couldn't identify the product in the demo store. What would you like: a course, an e-book, software, "
                "cloud storage or a website pack?" if is_english
                else "Je n'ai pas identifié le produit dans la boutique de démonstration. Que voulez-vous : un cours, un e-book, "
                     "un logiciel, du stockage cloud ou un pack site web ?",
                action="ask_ambiguity", steps=steps,
            )
        top_score = ranked[0][0]
        ranked = [(s, p) for s, p in ranked if s == top_score][:3]
        if len(ranked) > 1:
            options = "; ".join(f"{p['name']} ({p['unit_price']} {p['currency']})" for _, p in ranked)
            return reply(
                f"I found several options: {options}. Which one do you want?" if is_english
                else f"J'ai trouvé plusieurs options : {options}. Laquelle voulez-vous ?",
                action="ask_ambiguity", steps=steps,
            )

        product = ranked[0][1]
        res = tool_registry.execute("prepare_paypal_checkout", {
            "sku": product["sku"], "quantity": 1,
            "budget_limit": float(budget) if budget is not None else None,
            "budget_currency": "USD" if budget is not None else None,
            "user_id": uid, "user_request": user_message,
        })
        steps.append({"id": "step_2", "type": "prepare_paypal_checkout",
                      "label": "Checking budget & preparing PayPal checkout", "status": "completed" if res.success else "failed"})
        if not res.success:
            alternatives = res.data.get("alternatives_within_budget") or []
            alt_txt = ""
            if alternatives:
                listed = "; ".join(f"{p['name']} ({p['unit_price']} {p['currency']})" for p in alternatives)
                alt_txt = (f" Options within your budget: {listed}." if is_english else f" Options dans votre budget : {listed}.")
            return reply((res.error_message or "I could not prepare this checkout.") + alt_txt, steps=steps)
        checkout = res.data["checkout"]
        return reply(
            self._checkout_summary_text(checkout, is_english),
            action="prepare_paypal_checkout",
            action_id=checkout["checkout_id"],
            action_data={"type": "paypal_checkout", "action_id": checkout["checkout_id"], "checkout": checkout},
            steps=steps,
        )

    async def chat(
        self,
        user_message: str,
        financial_context: Optional[Dict[str, Any]] = None,
        conversation_history: Optional[List[Any]] = None,
        user_firstname: Optional[str] = None,
        user_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Point d'entrée principal de l'agent SIKA Pay.
        Boucle ReAct bornée avec Function Calling Gemini ; chaque tool passe par le ToolRegistry.
        """
        context = financial_context or {}
        firstname = user_firstname or context.get("user_firstname") or "there"
        is_english = self._is_english(user_message)

        # Salutation pure : réponse directe, aucun tool
        if self._is_pure_greeting(user_message):
            return self._chat_sika_pay_fallback(user_message, firstname, is_english, user_id, greeting=True)

        if not self.client:
            return self._chat_sika_pay_fallback(user_message, firstname, is_english, user_id)

        from ..agent.tool_registry import tool_registry
        from google.genai import types

        from ..agent.tools import AUTHORIZATION_ONLY_TOOLS
        from .agent_mandate_service import agent_mandate_service

        mandate = None
        if user_id and str(user_id).isdigit():
            try:
                mandate = agent_mandate_service.get(int(user_id))
            except Exception as e:  # base indisponible : on reste en mode « l'utilisateur confirme »
                logger.warning(f"[SIKA AGENT] Authorization lookup failed: {type(e).__name__}")
        authorized = bool(mandate and mandate.get("active"))
        excluded_tools = None if authorized else set(AUTHORIZATION_ONLY_TOOLS)

        safe_tools = tool_registry.get_gemini_tools(excluded_tools)
        lang_instruction = "Answer ONLY in English." if is_english else "Réponds UNIQUEMENT en français."
        system_instruction = self._sika_pay_instruction(firstname, lang_instruction, mandate)

        messages = []
        for msg in conversation_history or []:
            messages.append(types.Content(
                role="model" if msg.get("role") == "model" else "user",
                parts=[types.Part.from_text(text=msg.get("content", ""))]
            ))
        messages.append(types.Content(role="user", parts=[types.Part.from_text(text=user_message)]))

        max_steps = 5
        step = 0
        final_response_text = ""
        action_detected = "chat"
        action_data_detected = None
        action_id = None
        agent_steps: list[dict] = []

        # Libellés observables des étapes (jamais le raisonnement interne du modèle)
        _TOOL_LABELS = {
            "search_demo_catalog": "Searching the demo store catalog" if is_english else "Recherche dans le catalogue",
            "prepare_paypal_checkout": "Checking budget & preparing PayPal checkout" if is_english else "Vérification du budget et préparation PayPal",
            "get_paypal_checkout_status": "Verifying the status with PayPal" if is_english else "Vérification du statut auprès de PayPal",
            "list_recent_paypal_checkouts": "Reading your SIKA Pay history" if is_english else "Lecture de l'historique SIKA Pay",
            "confirm_checkout_with_authorization": "Confirming with your authorization" if is_english else "Confirmation avec votre autorisation",
            "search_web_products": "Comparing offers from online merchants" if is_english else "Comparaison des offres des marchands en ligne",
            "get_user_habits": "Reading your preferences" if is_english else "Lecture de vos préférences",
        }
        allowed_tool_names = set(tool_registry.agent_tool_names(excluded_tools))
        agent_confirmed = False
        gen_config = types.GenerateContentConfig(
            system_instruction=system_instruction,
            tools=safe_tools,
            temperature=0.2,
            # Les tools passent TOUJOURS par le ToolRegistry (contrôles, user_id serveur) : pas d'AFC SDK
            automatic_function_calling=types.AutomaticFunctionCallingConfig(disable=True),
        )

        while step < max_steps:
            step += 1
            try:
                response = await self.client.aio.models.generate_content(
                    model=self.model,
                    contents=messages,
                    config=gen_config,
                )
            except Exception as e:
                logger.error(f"Gemini error during generation: {e}")
                return self._chat_sika_pay_fallback(user_message, firstname, is_english, user_id)

            if getattr(response, 'candidates', None) and len(response.candidates) > 0:
                messages.append(response.candidates[0].content)

            if not response.function_calls:
                final_response_text = response.text or ""
                break

            for call in response.function_calls:
                logger.info(f"[SIKA AGENT] Gemini is calling tool: {call.name} with args: {call.args}")
                try:
                    if call.name not in allowed_tool_names:
                        raise PermissionError(f"Tool '{call.name}' is not available to the agent.")
                    call_args = dict(call.args) if call.args else {}
                    tool_func = tool_registry.get(call.name)
                    if tool_func:
                        import inspect
                        sig = inspect.signature(tool_func)
                        if "user_id" in sig.parameters:
                            # Toujours l'identité authentifiée côté serveur, jamais celle proposée par le modèle
                            call_args["user_id"] = str(user_id) if user_id else None
                        if "user_request" in sig.parameters:
                            call_args["user_request"] = user_message

                    tool_res = tool_registry.execute(call.name, call_args)
                    res_dict = tool_res.to_dict()
                    step_status = "completed" if tool_res.success else "failed"
                except Exception as e:
                    logger.error(f"Tool execution failed: {e}")
                    res_dict = {"success": False, "error_message": str(e)}
                    step_status = "failed"

                agent_steps.append({
                    "id": f"step_{len(agent_steps) + 1}",
                    "type": call.name,
                    "label": _TOOL_LABELS.get(call.name, "Analysing" if is_english else "Analyse en cours"),
                    "status": step_status,
                })

                messages.append(
                    types.Content(
                        role="user",
                        parts=[types.Part.from_function_response(name=call.name, response=res_dict)]
                    )
                )

                if call.name == "prepare_paypal_checkout" and res_dict.get("success"):
                    data = res_dict.get("data", {})
                    action_id = data.get("action_id")
                    action_detected = call.name
                    action_data_detected = {"type": "paypal_checkout", "action_id": action_id, "checkout": data.get("checkout")}
                    if not authorized:
                        # Sans autorisation, un checkout préparé rend la main à l'utilisateur
                        final_response_text = await self._explain_prepared_checkout(
                            messages, system_instruction, action_data_detected["checkout"], is_english
                        )
                        break
                elif call.name == "search_web_products" and res_dict.get("success") and not action_id:
                    data = res_dict.get("data", {})
                    web_products = data.get("products", [])[:3]
                    if web_products:
                        action_detected = "web_offers"
                        action_data_detected = {"type": "web_offers", "query": data.get("query"), "max_price": data.get("max_price"),
                                                "source": data.get("source"), "products": web_products}
                elif call.name == "confirm_checkout_with_authorization" and res_dict.get("success"):
                    data = res_dict.get("data", {})
                    action_id = data.get("action_id")
                    action_detected = "prepare_paypal_checkout"
                    action_data_detected = {"type": "paypal_checkout", "action_id": action_id, "checkout": data.get("checkout"),
                                            "confirmed_by": "AGENT"}
                    agent_confirmed = True

            if action_id and (not authorized or agent_confirmed):
                if agent_confirmed and not final_response_text:
                    final_response_text = await self._explain_prepared_checkout(
                        messages, system_instruction, action_data_detected["checkout"], is_english
                    )
                break

        if not final_response_text:
            final_response_text = (
                "I was unable to complete the analysis."
                if is_english
                else "Je n'ai pas pu terminer l'analyse."
            )

        prepared = bool(action_detected == "prepare_paypal_checkout" and action_id) and not agent_confirmed
        return {
            "response": final_response_text,
            "action": action_detected,
            "action_id": action_id,
            "action_data": action_data_detected,
            "sentiment": "positive",
            "suggestions": [],
            "provider": "GEMINI_API_AGENT" if self.provider == "gemini_api" else "VERTEX_AI_AGENT",
            "model": self.model,
            "requires_confirmation": prepared,
            "requires_biometric": prepared,
            "requires_security_validation": prepared,
            "status": "WAITING_CONFIRMATION" if prepared else "PROCESSED",
            "should_speak": True,
            "agent_steps": agent_steps,
            "language": "en" if is_english else "fr",
        }

# Instance globale utilisée dans l'application
sika_ai_service = SikaAIService()

# Compatibilité avec les anciens imports
SikaAI = SikaAIService
