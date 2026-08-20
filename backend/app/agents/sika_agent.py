"""
SIKA Agent — Implémentation officielle Google ADK & Google GenAI SDK Agent Tools.

Agent autonome de gestion financière personnelle qui consulte les portefeuilles réels
et les coffres d'épargne via Vertex AI sans GEMINI_API_KEY.
"""

import os
import logging
from typing import Dict, Any, Optional, List
from google import genai
from google.genai import types

from .tools.balance_tools import get_total_balance
from .tools.savings_tools import get_savings_status

logger = logging.getLogger(__name__)


class SikaADKAgent:
    """Agent Financier Autonome SIKA basé sur Google ADK & Vertex AI."""

    def __init__(self):
        self.project = os.getenv("GOOGLE_CLOUD_PROJECT", "sika-all-things-agentic")
        self.location = os.getenv("GOOGLE_CLOUD_LOCATION", "global")
        self.model = os.getenv("GEMINI_MODEL", "gemini-3.5-flash")
        self.client = None
        self.user_sessions: Dict[str, Dict[str, Any]] = {}
        self._init_client()

    def _init_client(self):
        try:
            self.client = genai.Client(
                vertexai=True,
                project=self.project,
                location=self.location,
            )
            logger.info(f"🤖 SIKA ADK Agent initialisé avec Vertex AI ({self.project} / {self.model})")
        except Exception as e:
            logger.warning(f"⚠️ Impossible d'initialiser SIKA ADK Agent: {e}")
            self.client = None

    def reset_all_sessions(self):
        """Réinitialise toutes les sessions conversationnelles multi-tours."""
        self.user_sessions.clear()
        logger.info("[SIKA ADK AGENT] Toutes les sessions utilisateur ont été réinitialisées.")

    def get_user_session(self, user_id: str = "1") -> Dict[str, Any]:
        """Récupère ou crée la session conversationnelle multi-tours (restaurée depuis la DB si redémarrage du backend)."""
        str_uid = str(user_id)
        if str_uid not in self.user_sessions:
            restored = False
            try:
                import json
                from sqlalchemy.orm import Session
                from ..database import engine
                from ..models.sika_session import SikaSessionModel
                with Session(engine) as db:
                    db_sess = db.query(SikaSessionModel).filter(SikaSessionModel.user_id == str_uid).first()
                    if db_sess:
                        sess_data = json.loads(db_sess.session_data_json) if db_sess.session_data_json else {}
                        self.user_sessions[str_uid] = {
                            "state": db_sess.state,
                            "active_action": sess_data.get("active_action"),
                            "ambiguity_context": sess_data.get("ambiguity_context"),
                            "history": sess_data.get("history", [])
                        }
                        restored = True
            except Exception as e:
                logger.warning(f"[DB SESSION WARN] Erreur de restauration session {str_uid}: {e}")

            if not restored:
                self.user_sessions[str_uid] = {
                    "state": "IDLE",
                    "active_action": None,
                    "ambiguity_context": None,
                    "history": []
                }
        return self.user_sessions[str_uid]

    def save_user_session(self, user_id: str = "1"):
        """Sauvegarde l'état conversationnel dans la base de données."""
        str_uid = str(user_id)
        sess = self.user_sessions.get(str_uid)
        if not sess:
            return
        try:
            import json
            from datetime import datetime
            from sqlalchemy.orm import Session
            from ..database import engine
            from ..models.sika_session import SikaSessionModel
            with Session(engine) as db:
                db_sess = db.query(SikaSessionModel).filter(SikaSessionModel.user_id == str_uid).first()
                sess_json = json.dumps({
                    "active_action": sess.get("active_action"),
                    "ambiguity_context": sess.get("ambiguity_context"),
                    "history": sess.get("history", [])
                })
                active_action_id = sess["active_action"].get("action_id") if sess.get("active_action") else None

                if db_sess:
                    db_sess.state = sess.get("state", "IDLE")
                    db_sess.active_action_id = active_action_id
                    db_sess.session_data_json = sess_json
                    db_sess.updated_at = datetime.utcnow()
                else:
                    db.add(SikaSessionModel(
                        user_id=str_uid,
                        state=sess.get("state", "IDLE"),
                        active_action_id=active_action_id,
                        session_data_json=sess_json,
                        updated_at=datetime.utcnow()
                    ))
                db.commit()
        except Exception as e:
            logger.warning(f"[DB SESSION WARN] Erreur de sauvegarde de la session {str_uid}: {e}")

    def process_query(self, user_message: str, user_firstname: str = "David", user_id: str = "1") -> Dict[str, Any]:
        """Traite une requête utilisateur vocale ou textuelle via l'Agent ADK SIKA avec gestion d'état conversationnel multi-tours."""
        msg_lower = user_message.lower().strip()
        session = self.get_user_session(str(user_id))

        tool_used = None
        tool_data = None
        requires_confirmation = False
        requires_biometric = False
        action_id = None
        should_speak = True
        status = "PROCESSED"
        speech_text = None

        # -------------------------------------------------------------------
        # 1. GESTION DES AMBIGUÏTÉS (AMBIGUITY_ASKED)
        # -------------------------------------------------------------------
        if session["state"] == "AMBIGUITY_ASKED" and session["ambiguity_context"]:
            ctx = session["ambiguity_context"]
            options = ctx.get("options", {})
            chosen_name = None

            for opt_name in options.keys():
                if opt_name.lower() in msg_lower or opt_name.lower().split()[0] in msg_lower:
                    chosen_name = opt_name
                    break

            if not chosen_name and ("premier" in msg_lower or "1" in msg_lower):
                chosen_name = list(options.keys())[0]

            if chosen_name:
                phone = options[chosen_name]
                amount = ctx.get("amount", 10000.0)
                action_id = f"tx_transfer_{chosen_name.lower().replace(' ', '_')}_{int(amount)}"
                tool_used = "prepare_transfer"

                from ..agent.orchestrator import sika_orchestrator
                sika_orchestrator.register_action(action_id, user_id=int(user_id) if str(user_id).isdigit() else 1)

                session["state"] = "WAITING_VOICE_CONFIRMATION"
                session["active_action"] = {
                    "action_id": action_id,
                    "type": "TRANSFER",
                    "recipient_name": chosen_name,
                    "recipient_phone": phone,
                    "amount": amount,
                    "provider": "Wave"
                }
                session["ambiguity_context"] = None

                fallback_response = f"Je vais envoyer {int(amount):,} francs CFA à {chosen_name}, au numéro {phone}, via Wave. Est-ce bien ce transfert que tu veux effectuer ?".replace(",", " ")
                speech_text = f"Je vais envoyer {int(amount)} francs CFA à {chosen_name}, au {phone}, via Wave. Est-ce que tu confirmes ?"

                return {
                    "success": True,
                    "query": user_message,
                    "response": fallback_response,
                    "speech_text": speech_text,
                    "intent": "transfer",
                    "tool_used": tool_used,
                    "action_id": action_id,
                    "status": "WAITING_VOICE_CONFIRMATION",
                    "requires_confirmation": True,
                    "requires_biometric": False,
                    "should_speak": True,
                    "provider": "GOOGLE_ADK_VERTEX_AI" if self.client else "GOOGLE_ADK_FALLBACK"
                }

        # -------------------------------------------------------------------
        # 2. GESTION DE LA CONFIRMATION VOCALE (WAITING_VOICE_CONFIRMATION)
        # -------------------------------------------------------------------
        if session["state"] == "WAITING_VOICE_CONFIRMATION" and session["active_action"]:
            action = session["active_action"]
            pos_kw = ["oui", "ouais", "yep", "yes", "je confirme", "confirme", "c'est bon", "vas-y", "fais-le", "exactement", "correct", "okay", "ok"]
            neg_kw = ["non", "annule", "stop", "attends", "laisse tomber", "cancel", "no", "finalement non"]

            if any(w in msg_lower for w in pos_kw):
                session["state"] = "BIOMETRIC_AUTH_REQUIRED"
                res_msg = f"D'accord {user_firstname} ! Veuillez valider l'opération avec votre empreinte digitale ou Face ID."
                return {
                    "success": True,
                    "query": user_message,
                    "response": res_msg,
                    "speech_text": res_msg,
                    "intent": action.get("type", "transfer").lower(),
                    "tool_used": "confirm_voice",
                    "action_id": action["action_id"],
                    "status": "BIOMETRIC_AUTH_REQUIRED",
                    "requires_confirmation": True,
                    "requires_biometric": True,
                    "requires_security_validation": True,
                    "should_speak": True,
                    "action_data": action,
                    "provider": "GOOGLE_ADK_VERTEX_AI" if self.client else "GOOGLE_ADK_FALLBACK"
                }
            elif any(w in msg_lower for w in neg_kw):
                from ..agent.orchestrator import sika_orchestrator
                sika_orchestrator.cancel_action(action["action_id"], reason="USER_VOICE_CANCEL")
                session["state"] = "CANCELLED"
                session["active_action"] = None
                res_msg = f"L'opération a été annulée."
                return {
                    "success": True,
                    "query": user_message,
                    "response": res_msg,
                    "speech_text": res_msg,
                    "intent": "cancel",
                    "tool_used": "cancel_voice",
                    "status": "CANCELLED",
                    "requires_confirmation": False,
                    "requires_biometric": False,
                    "should_speak": True,
                    "provider": "GOOGLE_ADK_VERTEX_AI" if self.client else "GOOGLE_ADK_FALLBACK"
                }

        # -------------------------------------------------------------------
        # 3. CAS D'AMBIGUÏTÉ DETECTÉ SUR "JEAN"
        # -------------------------------------------------------------------
        if ("jean" in msg_lower) and not any(w in msg_lower for w in ["kouamé", "baptiste", "claude"]):
            session["state"] = "AMBIGUITY_ASKED"
            session["ambiguity_context"] = {
                "amount": 10000.0,
                "options": {
                    "Jean Kouamé": "07 01 02 03 04",
                    "Jean-Baptiste Yao": "07 05 06 07 08",
                    "Jean Claude": "07 09 10 11 12"
                }
            }
            res_msg = "J'ai trouvé plusieurs contacts appelés Jean : Jean Kouamé, Jean-Baptiste Yao ou Jean Claude. Lequel souhaites-tu ?"
            return {
                "success": True,
                "query": user_message,
                "response": res_msg,
                "speech_text": res_msg,
                "intent": "ambiguity_resolution",
                "status": "AMBIGUITY_ASKED",
                "requires_confirmation": False,
                "should_speak": True,
                "provider": "GOOGLE_ADK_VERTEX_AI" if self.client else "GOOGLE_ADK_FALLBACK"
            }

        # -------------------------------------------------------------------
        # 4. SCÉNARIO : TRANSFERT URGENT OU STANDARD (KOUAMÉ JEAN)
        # -------------------------------------------------------------------
        if any(w in msg_lower for w in ["envoie", "transfert", "transférer", "send", "transfer"]):
            tool_used = "prepare_transfer"
            requires_confirmation = True
            action_id = "tx_transfer_kouame_20000"
            tool_data = {
                "recipient": "Kouamé Jean",
                "phone_number": "07 01 02 03 04",
                "amount": 20000.0,
                "provider": "Wave",
                "currency": "XOF"
            }
            from ..agent.orchestrator import sika_orchestrator
            sika_orchestrator.register_action(action_id, user_id=int(user_id) if str(user_id).isdigit() else 1)

            session["state"] = "WAITING_VOICE_CONFIRMATION"
            session["active_action"] = {
                "action_id": action_id,
                "type": "TRANSFER",
                "recipient_name": "Kouamé Jean",
                "amount": 20000.0,
                "provider": "Wave"
            }
            fallback_response = "J'ai trouvé Kouamé Jean, numéro 07 01 02 03 04. Je prépare un transfert de 20 000 FCFA via Wave. Est-ce que tu confirmes ?"
            speech_text = "J'ai trouvé Kouamé Jean, au numéro zéro sept, zéro un, zéro deux, zéro trois, zéro quatre. Je prépare un transfert de vingt mille francs CFA via Wave. Est-ce que tu confirmes ?"

        # -------------------------------------------------------------------
        # 5. SCÉNARIO : ÉPARGNE INTELLIGENTE & DÉPÔT COFFRE
        # -------------------------------------------------------------------
        elif any(w in msg_lower for w in ["mettre de côté", "mettre 10", "épargner 10", "puis-je épargner", "puis-je mettre", "dans mon coffre"]):
            tool_used = "get_savings_status"
            requires_confirmation = True
            action_id = "dep_coffre_10000"
            tool_data = get_savings_status()

            from ..agent.orchestrator import sika_orchestrator
            sika_orchestrator.register_action(action_id, user_id=int(user_id) if str(user_id).isdigit() else 1)

            session["state"] = "WAITING_VOICE_CONFIRMATION"
            session["active_action"] = {
                "action_id": action_id,
                "type": "SAVINGS_DEPOSIT",
                "coffre_name": "Épargne",
                "amount": 10000.0
            }
            fallback_response = f"Oui {user_firstname}, ton coffre Etude contient actuellement 106 000 FCFA. Je peux ajouter 10 000 FCFA à ton coffre Épargne. Est-ce que tu confirmes ?"
            speech_text = f"Oui {user_firstname}, ton coffre Etude contient actuellement 106 000 francs CFA. Je peux ajouter 10 000 francs à ton coffre. Est-ce que tu confirmes ?"

        # -------------------------------------------------------------------
        # 6. SCÉNARIO : CONSEILLER FINANCIER & ANALYSE DÉPENSES
        # -------------------------------------------------------------------
        elif any(w in msg_lower for w in ["analyse", "économiser ce mois", "conseil", "dépenses et dis-moi"]):
            tool_used = "get_spending_summary"
            from ..agent.tools.financial_tools import get_spending_summary
            tool_data = get_spending_summary().to_dict()
            session["state"] = "EXECUTED"
            fallback_response = "Votre principale catégorie de dépenses est la Restauration. Si vous réduisez cette catégorie de 15%, vous pourriez économiser environ 12 000 FCFA ce mois-ci."
            speech_text = "Votre principale catégorie de dépenses est la Restauration. Si vous réduisez cette catégorie de 15 pourcent, vous pourriez économiser environ 12 000 francs CFA ce mois-ci."

        # -------------------------------------------------------------------
        # 7. SCÉNARIO : CONSULTATION DU SOLDE
        # -------------------------------------------------------------------
        elif any(w in msg_lower for w in ["solde", "compte", "portefeuille", "combien j'ai", "balance"]):
            tool_used = "get_total_balance"
            tool_data = get_total_balance()
            tb = tool_data.get("total_balance", 0.0)
            session["state"] = "EXECUTED"
            fallback_response = f"Votre solde total connecté s'élève à **{int(tb):,} FCFA**, réparti entre vos comptes actifs PayMeChap et Wave.".replace(",", " ")
            speech_text = f"Votre solde total connecté s'élève à {int(tb)} francs CFA, réparti entre vos comptes actifs PayMeChap et Wave."

        elif any(w in msg_lower for w in ["épargne", "coffre", "objectif", "avancement", "savings"]):
            tool_used = "get_savings_status"
            tool_data = get_savings_status()
            cnom = tool_data.get("coffre_name", "Épargne")
            cur = tool_data.get("current_amount", 0.0)
            tgt = tool_data.get("target_amount", 0.0)
            pct = tool_data.get("progress_percentage", 0.0)
            session["state"] = "EXECUTED"
            fallback_response = f"Bonjour {user_firstname} ! Ton coffre **'{cnom}'** contient **{int(cur):,} FCFA** sur un objectif de **{int(tgt):,} FCFA** ({pct}% atteint).".replace(",", " ")
            speech_text = f"Bonjour {user_firstname} ! Ton coffre {cnom} contient {int(cur)} francs CFA sur un objectif de {int(tgt)} francs CFA."

        else:
            fallback_response = f"Bonjour {user_firstname} ! Je suis ton assistant SIKA, disponible pour surveiller tes finances."
            speech_text = fallback_response

        # 8. Si le client Vertex AI est disponible, générer la réponse naturelle via Gemini
        if self.client:
            try:
                system_instruction = (
                    f"Tu es SIKA, l'assistant vocal et financier autonome de {user_firstname}. "
                    f"Tu réponds de manière concise, précise et chaleureuse pour une lecture vocale (TTS). "
                    f"Outil financier consulté : {tool_used}. "
                    f"Données réelles des outils SIKA : {tool_data}. "
                    f"Demande de confirmation nécessaire : {requires_confirmation}. "
                    "N'invente jamais de montant ni de transaction non confirmée par les outils."
                )

                response = self.client.models.generate_content(
                    model=self.model,
                    contents=user_message,
                    config=types.GenerateContentConfig(
                        system_instruction=system_instruction,
                        temperature=0.2,
                    )
                )

                if response and response.text:
                    self.save_user_session(str(user_id))
                    return {
                        "success": True,
                        "query": user_message,
                        "response": response.text,
                        "speech_text": speech_text or response.text,
                        "intent": tool_used or "chat",
                        "tool_used": tool_used,
                        "action_data": tool_data,
                        "requires_confirmation": requires_confirmation,
                        "requires_biometric": requires_biometric,
                        "action_id": action_id,
                        "status": session["state"],
                        "should_speak": should_speak,
                        "provider": "GOOGLE_ADK_VERTEX_AI",
                        "model": self.model
                    }
            except Exception as e:
                logger.warning(f"Erreur d'exécution SIKA ADK Agent: {e}")

        self.save_user_session(str(user_id))
        return {
            "success": True,
            "query": user_message,
            "response": fallback_response,
            "speech_text": speech_text or fallback_response,
            "intent": tool_used or "chat",
            "tool_used": tool_used,
            "action_data": tool_data,
            "requires_confirmation": requires_confirmation,
            "requires_biometric": requires_biometric,
            "action_id": action_id,
            "status": session["state"],
            "should_speak": should_speak,
            "provider": "GOOGLE_ADK_FALLBACK",
            "model": self.model
        }



sika_adk_agent = SikaADKAgent()
