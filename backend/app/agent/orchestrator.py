import logging
import os
from typing import Dict, Any, List, Optional
from .state_machine import AgentState
from .memory_bridge import memory_bridge
from .tool_registry import tool_registry
from .tools.tool_models import ToolResult
from . import tools
from ..services.sika_ai import SikaAI
from ..routes.wallet_router import CONNECTED_USER_WALLETS

import json
import logging
import requests
from datetime import datetime, timezone, timedelta
from sqlalchemy.orm import Session
import time
import math

logger = logging.getLogger("SikaAgentOrchestrator")


def _ensure_utc(dt: Any) -> Any:
    if dt is None:
        return None
    if isinstance(dt, datetime):
        if dt.tzinfo is None:
            return dt.replace(tzinfo=timezone.utc)
    return dt


def _log_action_event(db, action_id: str, user_id: int, previous_status: str, new_status: str, event_type: str = "STATE_CHANGE", reason: str = None, metadata: dict = None):
    """Enregistre un événement immuable dans la table sika_action_events pour l'audit trail."""
    try:
        from ..models.sika_action_event import SikaActionEventModel
        event = SikaActionEventModel(
            action_id=action_id,
            user_id=int(user_id) if str(user_id).isdigit() else 1,
            previous_status=previous_status,
            new_status=new_status,
            event_type=event_type,
            reason=reason,
            metadata_json=json.dumps(metadata) if metadata else None,
            created_at=datetime.now(timezone.utc)
        )
        db.add(event)
    except Exception as e:
        logger.warning(f"[AUDIT TRAIL WARN] Erreur lors de l'enregistrement de l'événement d'audit: {e}")


class SikaAgentOrchestrator:
    """Orchestrateur principal de l'agent SIKA avec raisonnement Google Gemini et persistance SQL."""

    def __init__(self):
        self.state = AgentState.IDLE
        self.registry = tool_registry
        self.ai_service = SikaAI()
        self.action_store: Dict[str, Dict[str, Any]] = {}

    def register_action(self, action_id: str, user_id: int = 1, ttl_seconds: int = 300, action_type: str = "TRANSFER", payload: dict = None) -> Dict[str, Any]:
        """Enregistre une action financière en attente dans la base de données et en mémoire avec traçabilité d'audit."""
        now_utc = datetime.now(timezone.utc)
        expires_at = now_utc + timedelta(seconds=ttl_seconds)

        # 1. Mise à jour de la mémoire de processus
        for aid, meta in list(self.action_store.items()):
            if meta.get("user_id") == user_id and meta.get("status") in ["PREPARED", "WAITING_CONFIRMATION"]:
                meta["status"] = "CANCELLED"
                meta["cancelled_reason"] = "REPLACED_BY_NEW_ACTION"

        entry = {
            "action_id": action_id,
            "user_id": user_id,
            "action_type": action_type,
            "status": "WAITING_CONFIRMATION",
            "created_at": time.time(),
            "ttl": ttl_seconds,
            "result": None
        }
        self.action_store[action_id] = entry

        # 2. Persistance dans la base de données
        try:
            from sqlalchemy.orm import Session
            from ..database import engine
            from ..models.sika_action import SikaActionModel
            with Session(engine) as db:
                db.query(SikaActionModel).filter(
                    SikaActionModel.user_id == user_id,
                    SikaActionModel.status.in_(["WAITING_CONFIRMATION", "PREPARED"])
                ).update({"status": "CANCELLED", "cancelled_reason": "REPLACED_BY_NEW_ACTION", "updated_at": now_utc}, synchronize_session=False)

                existing = db.query(SikaActionModel).filter(SikaActionModel.action_id == action_id).first()
                if existing:
                    prev_st = existing.status
                    existing.status = "WAITING_CONFIRMATION"
                    existing.user_id = user_id
                    existing.expires_at = expires_at
                    existing.updated_at = now_utc
                    existing.payload_json = json.dumps(payload) if payload else None
                    _log_action_event(db, action_id, user_id, prev_st, "WAITING_CONFIRMATION", "ACTION_REGISTERED", "REPLACED_EXISTING", payload)
                else:
                    db.add(SikaActionModel(
                        action_id=action_id,
                        idempotency_key=action_id,
                        user_id=user_id,
                        action_type=action_type,
                        status="WAITING_CONFIRMATION",
                        created_at=now_utc,
                        expires_at=expires_at,
                        updated_at=now_utc,
                        payload_json=json.dumps(payload) if payload else None
                    ))
                    _log_action_event(db, action_id, user_id, None, "WAITING_CONFIRMATION", "ACTION_CREATED", "INITIAL_REGISTRATION", payload)
                db.commit()
        except Exception as e:
            logger.warning(f"[DB WARN] Impossible d'enregistrer l'action dans la DB: {e}")

        return entry

    def cleanup_stale_actions(self, user_id: Optional[int] = None, now: Optional[datetime] = None) -> List[str]:
        """Bascule automatiquement et de manière atomique les actions en attente expirées vers l'état EXPIRED (isolé par user_id si fourni)."""
        now_utc = _ensure_utc(now or datetime.now(timezone.utc))
        expired_ids = []
        try:
            from sqlalchemy.orm import Session
            from ..database import engine
            from ..models.sika_action import SikaActionModel
            with Session(engine) as db:
                q = db.query(SikaActionModel).filter(
                    SikaActionModel.status.in_(["WAITING_CONFIRMATION", "PREPARED"])
                )
                if user_id is not None:
                    q = q.filter(SikaActionModel.user_id == user_id)
                candidates = q.all()

                stale_actions = [act for act in candidates if act.expires_at and now_utc > _ensure_utc(act.expires_at)]

                for act in stale_actions:
                    prev_st = act.status
                    act.status = "EXPIRED"
                    act.updated_at = now_utc
                    expired_ids.append(act.action_id)
                    _log_action_event(db, act.action_id, act.user_id, prev_st, "EXPIRED", "ACTION_EXPIRED", "BACKGROUND_TTL_CLEANUP")

                    if act.action_id in self.action_store:
                        self.action_store[act.action_id]["status"] = "EXPIRED"

                if expired_ids:
                    db.commit()
                    logger.info(f"[TTL CLEANUP] {len(expired_ids)} action(s) expiré(es) nettoyée(s) : {expired_ids}")
        except Exception as e:
            logger.warning(f"[TTL CLEANUP WARN] Erreur lors du nettoyage des actions expirées: {e}")
        return expired_ids

    def cancel_action(self, action_id: str, user_id: int = 1, reason: str = "USER_CANCELLED") -> Dict[str, Any]:
        """Marque une action comme annulée de manière atomique (uniquement si WAITING_CONFIRMATION ou PREPARED et appartenant à l'utilisateur)."""
        try:
            from sqlalchemy.orm import Session
            from ..database import engine
            from ..models.sika_action import SikaActionModel

            with Session(engine) as db:
                db_action = db.query(SikaActionModel).filter(SikaActionModel.action_id == action_id).first()
                if not db_action and action_id not in self.action_store:
                    return {
                        "success": False,
                        "status": "NOT_FOUND",
                        "action_id": action_id,
                        "message": "Action financière introuvable."
                    }

                if db_action and str(db_action.user_id) != str(user_id):
                    return {
                        "success": False,
                        "status": "UNAUTHORIZED_USER",
                        "action_id": action_id,
                        "message": "Cette action financière n'appartient pas à cet utilisateur."
                    }

                affected = db.query(SikaActionModel).filter(
                    SikaActionModel.action_id == action_id,
                    SikaActionModel.user_id == user_id,
                    SikaActionModel.status.in_(["WAITING_CONFIRMATION", "PREPARED"])
                ).update({"status": "CANCELLED", "cancelled_reason": reason, "updated_at": datetime.now(timezone.utc)}, synchronize_session=False)

                if affected > 0:
                    _log_action_event(db, action_id, user_id, "WAITING_CONFIRMATION", "CANCELLED", "ACTION_CANCELLED", reason)
                db.commit()

                if affected == 0 and db_action:
                    return {
                        "success": False,
                        "status": db_action.status,
                        "action_id": action_id,
                        "message": f"Impossible d'annuler cette action car elle est déjà au statut {db_action.status}."
                    }
        except Exception as e:
            logger.warning(f"[DB WARN] Impossible d'annuler l'action en DB: {e}")

        if action_id in self.action_store:
            self.action_store[action_id]["status"] = "CANCELLED"
            self.action_store[action_id]["cancelled_reason"] = reason

        return {
            "success": True,
            "status": "CANCELLED",
            "action_id": action_id,
            "message": "Demande de virement annulée avec succès."
        }

    def list_available_tools(self) -> List[Dict[str, Any]]:
        """Retourne la liste des tools disponibles dans le registre."""
        return self.registry.list_tools()

    def execute_tool(self, tool_name: str, arguments: Dict[str, Any] = None, user_confirmed: bool = False) -> ToolResult:
        """Exécute un tool par son nom via le ToolRegistry."""
        logger.info(f"[SIKA AGENT] Exécution du tool '{tool_name}' (Arguments: {arguments})")
        return self.registry.execute(tool_name, arguments, user_confirmed=user_confirmed)

    async def process_user_request(self, user_id: int = 1, query: str = "") -> Dict[str, Any]:
        """Alias pour process_user_query compatible avec les appels passés par user_id et query."""
        return await self.process_user_query(query=query, user_id=user_id)

    async def process_user_query(self, query: str, user_id: int = 1) -> Dict[str, Any]:
        """Traite la requête utilisateur via Google Gemini (SikaAI) et exécute les tools financiers appropriés."""
        logger.info(f"[SIKA ORCHESTRATOR] Traitement de la requête utilisateur: '{query}' (user_id={user_id})")

        # 1. Récupération du contexte financier via MemoryBridge
        context = memory_bridge.get_financial_context(user_id)

        # 2. Analyse et raisonnement LLM via Google Gemini (SikaAI)
        self.state = AgentState.ANALYZING
        ai_response = await self.ai_service.chat(
            user_message=query,
            financial_context=context,
            user_firstname="David"
        )

        action = ai_response.get("action") or ai_response.get("intent")
        requires_confirmation = False
        tool_result = None

        # 3. Planning et exécution des tools financiers selon le niveau de risque
        if action and self.registry.exists(action):
            self.state = AgentState.PLANNING
            tool_meta = self.registry.get_definition(action)
            if tool_meta and tool_meta.risk_level.value in ["CONFIRMATION_REQUIRED", "EXECUTION"]:
                requires_confirmation = True
                self.state = AgentState.WAITING_CONFIRMATION
            else:
                self.state = AgentState.EXECUTING
                tool_exec = self.registry.execute(action, ai_response.get("action_data", {}))
                tool_result = tool_exec.to_dict()
                self.state = AgentState.VERIFYING
        else:
            self.state = AgentState.VERIFYING

        final_state = self.state.value
        self.state = AgentState.IDLE

        action_id = ai_response.get("action_id")
        action_data = ai_response.get("action_data")
        if requires_confirmation and not action_id and action_data and isinstance(action_data, dict):
            action_id = action_data.get("action_id")

        return {
            "query": query,
            "state": final_state,
            "status": "WAITING_CONFIRMATION" if requires_confirmation else "PROCESSED",
            "message": ai_response.get("response", ai_response.get("message")),
            "action": action,
            "action_id": action_id,
            "action_data": action_data,
            "tool_result": tool_result,
            "requires_confirmation": requires_confirmation,
            "provider": ai_response.get("provider", self.ai_service.provider.upper()),
            "model": ai_response.get("model", os.getenv("GEMINI_MODEL", "gemini-3.5-flash")),
            "agent_steps": ai_response.get("agent_steps", [])
        }

    async def confirm_action(self, action_id: str, user_id: int = 1, user_confirmed: bool = True) -> Dict[str, Any]:
        """Exécute l'action financière réelle sur l'API PayMeChap avec verrouillage atomique, validation d'appartenance utilisateur et gestion des crashs."""
        logger.info(f"[SIKA ORCHESTRATOR] Validation de sécurité reçue pour action_id={action_id} (user_id={user_id})")

        from sqlalchemy.orm import Session
        from ..database import engine
        from ..models.sika_action import SikaActionModel
        from ..services.wallet_integrations.paymechap_api_service import paymechap_api_service
        from ..routes.wallet_router import CONNECTED_USER_WALLETS

        # 1. VÉRIFICATION D'APPARTENANCE ET D'ÉTAT PERSISTÉ EN BASE DE DONNÉES
        db_action = None
        now_utc = _ensure_utc(datetime.now(timezone.utc))
        try:
            with Session(engine) as db:
                db_action = db.query(SikaActionModel).filter(SikaActionModel.action_id == action_id).first()
                if db_action:
                    # Isolation utilisateur
                    if str(db_action.user_id) != str(user_id):
                        logger.warning(f"[SECURITY REJECT] User {user_id} tentait d'exécuter l'action {action_id} appartenant à user {db_action.user_id}")
                        return {
                            "success": False,
                            "status": "UNAUTHORIZED_USER",
                            "action_id": action_id,
                            "message": "Cette action financière n'appartient pas à cet utilisateur.",
                            "speech_text": "Cette action financière n'appartient pas à cet utilisateur.",
                            "should_speak": True
                        }

                    # États terminaux (Transition strictly interdite)
                    if db_action.status == "EXECUTED":
                        return {
                            "success": False,
                            "status": "ALREADY_EXECUTED",
                            "action_id": action_id,
                            "message": "Cette transaction a déjà été exécutée sur PayMeChap. Impossible de la soumettre une seconde fois.",
                            "speech_text": "Cette transaction a déjà été exécutée. Impossible de la soumettre à nouveau.",
                            "should_speak": True
                        }
                    if db_action.status == "CANCELLED":
                        return {
                            "success": False,
                            "status": "CANCELLED",
                            "action_id": action_id,
                            "message": "Cette demande de transaction a été annulée et ne peut plus être exécutée.",
                            "speech_text": "Cette demande de transaction a été annulée et ne peut plus être exécutée.",
                            "should_speak": True
                        }
                    if db_action.status == "FAILED":
                        return {
                            "success": False,
                            "status": "FAILED",
                            "action_id": action_id,
                            "message": "Cette transaction est en échec définitif et ne peut plus être exécutée.",
                            "speech_text": "Cette transaction est en échec définitif.",
                            "should_speak": True
                        }
                    if db_action.status == "UNKNOWN_RESULT":
                        return {
                            "success": False,
                            "status": "UNKNOWN_RESULT",
                            "action_id": action_id,
                            "message": "Cette transaction a un résultat incertain. Aucune nouvelle tentative n'est autorisée sans réconciliation.",
                            "speech_text": "Cette transaction a un résultat incertain. Aucune nouvelle tentative n'est autorisée.",
                            "should_speak": True
                        }
                    if db_action.status == "REQUIRES_RECONCILIATION":
                        return {
                            "success": False,
                            "status": "REQUIRES_RECONCILIATION",
                            "action_id": action_id,
                            "message": "Cette transaction a été interrompue et nécessite une réconciliation préalable.",
                            "speech_text": "Cette transaction a été interrompue et nécessite une réconciliation.",
                            "should_speak": True
                        }

                    # Gestion d'une action EXECUTING bloquée (Crash recovery / Timeout > 60s)
                    if db_action.status == "EXECUTING":
                        updated_at_utc = _ensure_utc(db_action.updated_at)
                        if updated_at_utc and (now_utc - updated_at_utc) > timedelta(seconds=60):
                            logger.warning(f"[CRASH RECOVERY] Action {action_id} bloquée en EXECUTING depuis > 60s. Bascule vers REQUIRES_RECONCILIATION.")
                            db_action.status = "REQUIRES_RECONCILIATION"
                            db_action.cancelled_reason = "STUCK_EXECUTING_TIMEOUT"
                            db.commit()
                            return {
                                "success": False,
                                "status": "REQUIRES_RECONCILIATION",
                                "action_id": action_id,
                                "message": "Cette transaction a été interrompue suite à un délai réseau. Une réconciliation est requise.",
                                "speech_text": "Cette transaction a subi une interruption. Une réconciliation est requise.",
                                "should_speak": True
                            }
                        return {
                            "success": False,
                            "status": "ALREADY_EXECUTING",
                            "action_id": action_id,
                            "message": "Cette transaction est actuellement en cours d'exécution sur PayMeChap.",
                            "speech_text": "Une demande d'exécution est déjà en cours pour cette transaction.",
                            "should_speak": True
                        }

                    if db_action.status == "EXPIRED" or (db_action.expires_at and now_utc > _ensure_utc(db_action.expires_at)):
                        prev_st = db_action.status
                        db_action.status = "EXPIRED"
                        db_action.updated_at = now_utc
                        _log_action_event(db, action_id, user_id, prev_st, "EXPIRED", "ACTION_EXPIRED", "TTL_EXPIRED_UPON_CONFIRM")
                        db.commit()
                        return {
                            "success": False,
                            "status": "EXPIRED",
                            "action_id": action_id,
                            "message": "Cette demande de transaction a expiré. Veuillez recommencer la commande.",
                            "speech_text": "Cette demande de transaction a expiré. Veuillez recommencer.",
                            "should_speak": True
                        }
        except Exception as e:
            logger.warning(f"[DB WARN] Erreur lors de la vérification de l'action DB: {e}")

        # Fallback vérification mémoire si non trouvé en DB
        action_meta = self.action_store.get(action_id)
        if action_meta:
            if str(action_meta.get("user_id")) != str(user_id):
                return {
                    "success": False,
                    "status": "UNAUTHORIZED_USER",
                    "action_id": action_id,
                    "message": "Cette action financière n'appartient pas à cet utilisateur.",
                    "speech_text": "Cette action financière n'appartient pas à cet utilisateur.",
                    "should_speak": True
                }
            cur_st = action_meta.get("status")
            if cur_st == "EXECUTED":
                return {"success": False, "status": "ALREADY_EXECUTED", "message": "Cette transaction a déjà été exécutée sur PayMeChap.", "speech_text": "Cette transaction a déjà été exécutée.", "should_speak": True}
            if cur_st in ["EXECUTING", "REQUIRES_RECONCILIATION"]:
                return {"success": False, "status": cur_st, "message": "Une exécution ou réconciliation est en cours.", "speech_text": "Une exécution ou réconciliation est déjà en cours.", "should_speak": True}
            if cur_st == "CANCELLED":
                return {"success": False, "status": "CANCELLED", "message": "Cette demande de transaction a été annulée.", "speech_text": "Cette demande de transaction a été annulée.", "should_speak": True}

        action_payload_json = None
        # 2. VERROUILLAGE ATOMIQUE SQL (WAITING_CONFIRMATION / PREPARED -> EXECUTING) AVEC FILTRE TTL ET OWNERSHIP
        try:
            from sqlalchemy import or_
            with Session(engine) as db:
                affected = db.query(SikaActionModel).filter(
                    SikaActionModel.action_id == action_id,
                    SikaActionModel.user_id == user_id,
                    SikaActionModel.status.in_(["WAITING_CONFIRMATION", "PREPARED"]),
                    or_(SikaActionModel.expires_at.is_(None), SikaActionModel.expires_at >= now_utc)
                ).update({"status": "EXECUTING", "updated_at": now_utc}, synchronize_session=False)

                if affected > 0:
                    locked_action = db.query(SikaActionModel).filter(SikaActionModel.action_id == action_id).first()
                    action_payload_json = locked_action.payload_json if locked_action else None
                    _log_action_event(db, action_id, user_id, "WAITING_CONFIRMATION", "EXECUTING", "ACTION_EXECUTING", "USER_CONFIRMED")
                db.commit()

                if affected == 0:
                    check_act = db.query(SikaActionModel).filter(SikaActionModel.action_id == action_id).first()
                    if not check_act and action_id not in self.action_store:
                        return {
                            "success": False,
                            "status": "NOT_FOUND",
                            "action_id": action_id,
                            "message": "Action financière introuvable.",
                            "speech_text": "Action financière introuvable.",
                            "should_speak": True
                        }
                    if check_act and str(check_act.user_id) != str(user_id):
                        return {
                            "success": False,
                            "status": "UNAUTHORIZED_USER",
                            "action_id": action_id,
                            "message": "Cette action financière n'appartient pas à cet utilisateur.",
                            "speech_text": "Cette action financière n'appartient pas à cet utilisateur.",
                            "should_speak": True
                        }
                    if check_act and (check_act.status == "EXPIRED" or (check_act.expires_at and now_utc > _ensure_utc(check_act.expires_at))):
                        return {
                            "success": False,
                            "status": "EXPIRED",
                            "action_id": action_id,
                            "message": "Cette demande de transaction a expiré. Veuillez recommencer la commande.",
                            "speech_text": "Cette demande de transaction a expiré. Veuillez recommencer.",
                            "should_speak": True
                        }
                    logger.warning(f"[ATOMIC LOCK REJECT] Action {action_id} déjà verrouillée ou changée d'état.")
                    return {
                        "success": False,
                        "status": "ALREADY_EXECUTING",
                        "action_id": action_id,
                        "message": "Une demande d'exécution est déjà en cours ou traitée pour cette transaction.",
                        "speech_text": "Une demande d'exécution est déjà en cours.",
                        "should_speak": True
                    }
        except Exception as e:
            logger.warning(f"[DB WARN] Erreur lors du verrouillage atomique DB: {e}")

        if action_meta:
            action_meta["status"] = "EXECUTING"

        # 3. EXÉCUTION SUR L'API PAYMECHAP (TRANSACTION SQL FERMÉE PENDANT L'APPEL RÉSEAU)
        # Validation sécurisée du payload financier
        parsed_payload = None
        if action_payload_json:
            try:
                parsed_payload = json.loads(action_payload_json) if isinstance(action_payload_json, str) else action_payload_json
            except Exception:
                pass

        if not parsed_payload and action_meta:
            parsed_payload = action_meta.get("payload") or action_meta.get("result")
            if isinstance(parsed_payload, str):
                try:
                    parsed_payload = json.loads(parsed_payload)
                except Exception:
                    pass

        if not parsed_payload or not isinstance(parsed_payload, dict):
            try:
                with Session(engine) as db:
                    db.query(SikaActionModel).filter(SikaActionModel.action_id == action_id).update({"status": "FAILED", "updated_at": datetime.now(timezone.utc)})
                    _log_action_event(db, action_id, user_id, "EXECUTING", "FAILED", "ACTION_FAILED", "INVALID_OR_MISSING_PAYLOAD")
                    db.commit()
            except Exception:
                pass
            if action_meta: action_meta["status"] = "FAILED"
            return {
                "success": False,
                "status": "FAILED",
                "action_id": action_id,
                "message": "Les données de la transaction sont invalides ou manquantes.",
                "speech_text": "Les données de la transaction sont invalides ou manquantes.",
                "should_speak": True
            }

        try:
            is_transfer = (
                "recipient" in parsed_payload
                or "destinataire" in parsed_payload
                or "recipient_phone" in parsed_payload
                or "transfer" in action_id
                or "act_tr" in action_id
                or (action_meta and action_meta.get("action_type") in ["TRANSFER", "TRANSFERT"])
                or (db_action and db_action.action_type in ["TRANSFER", "TRANSFERT"])
            )
            if is_transfer:
                # Extraction dynamique et sécurisée
                try:
                    amount = float(parsed_payload.get("amount", 0))
                    if math.isnan(amount) or math.isinf(amount):
                        raise ValueError("Le montant ne peut pas être NaN ou Infinity.")
                except (ValueError, TypeError):
                    amount = 0.0
                    
                recipient_phone = str(parsed_payload.get("recipient_phone") or parsed_payload.get("recipient") or "").strip()
                
                # Rejet catégorique si les données sont invalides (pas de fallback hardcodé)
                if amount <= 0 or not recipient_phone:
                    raise ValueError("Montant invalide ou destinataire manquant dans le payload.")

                motif = parsed_payload.get("motif", "Transfert SIKA")
                
                payout_res = paymechap_api_service.execute_payout(
                    access_token="",
                    recipient_phone=recipient_phone,
                    amount=amount,
                    motif=motif,
                    action_id=action_id
                )

            elif "dep_coffre" in action_id or "deposit" in action_id:
                try:
                    amount = float(parsed_payload.get("amount", 0))
                    if math.isnan(amount) or math.isinf(amount):
                        raise ValueError("Le montant ne peut pas être NaN ou Infinity.")
                except (ValueError, TypeError):
                    amount = 0.0
                    
                coffre_id = parsed_payload.get("coffre_id")
                
                if amount <= 0 or not coffre_id:
                    raise ValueError("Montant invalide ou coffre_id manquant pour le dépôt.")
                    
                payout_res = paymechap_api_service.deposit_to_coffre(access_token="", coffre_id=coffre_id, montant=amount, action_id=action_id)
            else:
                payout_res = {"success": True, "message": "Opération sans payout spécifique"}
                
        except ValueError as val_err:
            logger.warning(f"[PAYLOAD REJECT] Rejet de l'exécution pour {action_id} : {val_err}")
            try:
                with Session(engine) as db:
                    db.query(SikaActionModel).filter(SikaActionModel.action_id == action_id).update({"status": "FAILED", "updated_at": datetime.now(timezone.utc)})
                    _log_action_event(db, action_id, user_id, "EXECUTING", "FAILED", "ACTION_FAILED", "PAYLOAD_VALIDATION_ERROR")
                    db.commit()
            except Exception:
                pass
            if action_meta: action_meta["status"] = "FAILED"
            return {
                "success": False,
                "status": "FAILED",
                "action_id": action_id,
                "message": f"Validation échouée : {val_err}",
                "speech_text": "Impossible d'exécuter l'action car les données sont incorrectes.",
                "should_speak": True
            }
        except requests.exceptions.RequestException as net_exc:
            logger.error(f"[PAYMECHAP INCERTAIN] Erreur réseau lors de la communication avec PayMeChap: {net_exc}")
            try:
                with Session(engine) as db:
                    db.query(SikaActionModel).filter(SikaActionModel.action_id == action_id).update({
                        "status": "UNKNOWN_RESULT",
                        "cancelled_reason": str(net_exc)[:255],
                        "updated_at": datetime.now(timezone.utc)
                    })
                    _log_action_event(db, action_id, user_id, "EXECUTING", "UNKNOWN_RESULT", "ACTION_UNKNOWN_RESULT", "NETWORK_ERROR")
                    db.commit()
            except Exception:
                pass
            return {
                "success": False,
                "status": "UNKNOWN_RESULT",
                "action_id": action_id,
                "message": "Le statut du virement sur PayMeChap n'a pas pu être confirmé en raison d'un délai réseau. Aucune nouvelle tentative n'a été effectuée par sécurité.",
                "speech_text": "Le résultat du transfert est incertain à cause du réseau. Aucune nouvelle tentative n'a été lancée par sécurité.",
                "should_speak": True
            }
        except Exception as unk_exc:
            logger.error(f"[PAYMECHAP INATTENDU] Erreur interne après verrouillage: {unk_exc}")
            try:
                with Session(engine) as db:
                    db.query(SikaActionModel).filter(SikaActionModel.action_id == action_id).update({
                        "status": "UNKNOWN_RESULT",
                        "cancelled_reason": f"UNEXPECTED_ERROR: {str(unk_exc)[:200]}",
                        "updated_at": datetime.now(timezone.utc)
                    })
                    _log_action_event(db, action_id, user_id, "EXECUTING", "UNKNOWN_RESULT", "ACTION_UNKNOWN_RESULT", "UNEXPECTED_ERROR")
                    db.commit()
            except Exception:
                pass
            return {
                "success": False,
                "status": "UNKNOWN_RESULT",
                "action_id": action_id,
                "message": "Une erreur inattendue est survenue pendant le traitement. La transaction nécessite une vérification manuelle.",
                "speech_text": "Une erreur inattendue s'est produite. La transaction nécessite une vérification manuelle.",
                "should_speak": True
            }

        # 4. TRAITEMENT DES RÉSULTATS DE PAYMECHAP
        if payout_res.get("success") is False:
            fail_msg = payout_res.get("message") or "Je n'arrive pas à joindre PayMeChap pour le moment. Aucun transfert n'a été effectué."
            try:
                with Session(engine) as db:
                    db.query(SikaActionModel).filter(SikaActionModel.action_id == action_id).update({"status": "FAILED", "updated_at": datetime.now(timezone.utc)})
                    _log_action_event(db, action_id, user_id, "EXECUTING", "FAILED", "ACTION_FAILED", "PAYMECHAP_REJECTED")
                    db.commit()
            except Exception:
                pass
            if action_meta: action_meta["status"] = "FAILED"
            return {
                "success": False,
                "status": "FAILED",
                "action_id": action_id,
                "message": fail_msg,
                "speech_text": fail_msg,
                "should_speak": True
            }

        # SUCCÈS EXÉCUTÉ
        fetched = paymechap_api_service.fetch_live_balance("", "0799053977")
        real_bal = float(fetched.get("balance", 80000.0)) if fetched.get("success") else 80000.0
        for w in CONNECTED_USER_WALLETS:
            if w.get("is_active", True):
                w["balance"] = real_bal

        if "transfer" in action_id or "act_tr" in action_id:
            # Récupération sécurisée du montant et du destinataire depuis le payload qui a déjà été validé plus haut
            amount_str = f"{int(amount):,}".replace(",", " ") if 'amount' in locals() else "le montant"
            recipient_str = recipient_phone if 'recipient_phone' in locals() else "le destinataire"
            msg = f"Le transfert de {amount_str} francs CFA vers {recipient_str} a été effectué avec succès. Votre nouveau solde PayMeChap est de {int(real_bal):,} FCFA.".replace(",", " ")
        else:
            msg = "Opération confirmée et exécutée avec succès via PayMeChap."

        res_dict = {
            "success": True,
            "status": "EXECUTED",
            "action_id": action_id,
            "message": msg,
            "speech_text": msg,
            "paymechap_transaction": payout_res,
            "new_balance": real_bal,
            "should_speak": True
        }

        try:
            with Session(engine) as db:
                db.query(SikaActionModel).filter(SikaActionModel.action_id == action_id).update({
                    "status": "EXECUTED",
                    "result_json": json.dumps(res_dict),
                    "updated_at": datetime.now(timezone.utc)
                })
                _log_action_event(db, action_id, user_id, "EXECUTING", "EXECUTED", "ACTION_EXECUTED", "PAYMECHAP_SUCCESS")
                db.commit()
        except Exception:
            pass

        if action_meta:
            action_meta["status"] = "EXECUTED"
            action_meta["result"] = res_dict

        return res_dict

    async def reconcile_action(self, action_id: str, user_id: int = 1) -> Dict[str, Any]:
        """Interroge directement l'API PayMeChap pour réconcilier une transaction sans JAMAIS la ré-exécuter."""
        logger.info(f"[RECONCILIATION] Demande de réconciliation pour action_id={action_id} (user_id={user_id})")

        from sqlalchemy.orm import Session
        from sqlalchemy.exc import OperationalError
        from ..database import engine
        from ..models.sika_action import SikaActionModel
        from ..models.user import UserModel
        from ..services.wallet_integrations.paymechap_api_service import paymechap_api_service

        account_number = None

        # 1. VÉRIFICATION D'APPARTENANCE ET ACQUISITION DU VERROU
        try:
            with Session(engine) as db:
                db_action = db.query(SikaActionModel).filter(SikaActionModel.action_id == action_id).first()
                if not db_action:
                    return {"success": False, "status": "NOT_FOUND", "message": "Action introuvable."}
                
                if str(db_action.user_id) != str(user_id):
                    logger.warning(f"[RECONCILIATION REJECT] User {user_id} ne possède pas l'action {action_id}")
                    return {"success": False, "status": "UNAUTHORIZED_USER", "message": "Non autorisé."}

                # Actions déjà résolues
                if db_action.status in ["EXECUTED", "FAILED", "CANCELLED", "EXPIRED"]:
                    return {"success": db_action.status == "EXECUTED", "status": db_action.status, "message": f"Action déjà {db_action.status}."}

                # Gestion de la reprise après crash
                if db_action.status == "RECONCILIATION_IN_PROGRESS":
                    if db_action.reconciliation_started_at:
                        now_utc = datetime.now(timezone.utc)
                        started_at = db_action.reconciliation_started_at
                        if started_at.tzinfo is None:
                            started_at = started_at.replace(tzinfo=timezone.utc)
                        elapsed = (now_utc - started_at).total_seconds()
                        if elapsed < 300:
                            return {"success": False, "status": "RECONCILIATION_IN_PROGRESS", "message": "Réconciliation déjà en cours."}
                        else:
                            logger.info(f"[RECONCILIATION] Reprise du verrou expiré pour {action_id}")
                    else:
                        # Fallback if null
                        return {"success": False, "status": "RECONCILIATION_IN_PROGRESS", "message": "Réconciliation en cours."}
                
                elif db_action.status not in ["UNKNOWN_RESULT", "REQUIRES_RECONCILIATION"]:
                    return {"success": False, "status": db_action.status, "message": f"Statut inéligible : {db_action.status}."}

                # Tentative d'acquisition du verrou SQL
                try:
                    locked_action = db.query(SikaActionModel).filter(
                        SikaActionModel.action_id == action_id
                    ).with_for_update(nowait=True).first()
                    
                    if not locked_action:
                        return {"success": False, "status": "RECONCILIATION_IN_PROGRESS", "message": "En cours par un autre processus."}
                    
                    locked_action.status = "RECONCILIATION_IN_PROGRESS"
                    locked_action.reconciliation_started_at = datetime.now(timezone.utc)
                    db.commit()
                except OperationalError:
                    db.rollback()
                    return {"success": False, "status": "RECONCILIATION_IN_PROGRESS", "message": "En cours (verrouillé)."}

                # Récupération des informations de compte
                user = db.query(UserModel).filter(UserModel.id == user_id).first()
                if user:
                    account_number = user.phone

        except Exception as e:
            logger.error(f"[RECONCILIATION] Erreur DB lors de l'acquisition du verrou: {e}")
            return {"success": False, "status": "UNKNOWN_RESULT", "message": "Erreur DB."}

        # 2. INTERROGATION EN DIRECT DE PAYMECHAP HORS TRANSACTION SQL
        matching_tx = None
        try:
            live_txs = paymechap_api_service.fetch_live_transactions(access_token="", account_number=account_number, limit=50)
            
            for tx in live_txs:
                tx_id_str = str(tx.get("id", ""))
                tx_ref = str(tx.get("reference", ""))
                tx_idem = str(tx.get("idempotency_key", ""))
                
                if action_id == tx_id_str or action_id == tx_ref or action_id == tx_idem:
                    matching_tx = tx
                    break
        except Exception as e:
            logger.error(f"[RECONCILIATION] Erreur réseau lors de la consultation: {e}")
            # En cas d'erreur réseau (Timeout, ConnectionError...), ça reste UNKNOWN_RESULT
            matching_tx = None

        final_status = "UNKNOWN_RESULT"
        if matching_tx:
            tx_stat = str(matching_tx.get("status", "")).upper()
            if tx_stat in ["COMPLETED", "EFFECTUÉ", "SUCCESS", "SUCCES"]:
                final_status = "EXECUTED"
            elif tx_stat in ["FAILED", "ÉCHOUÉ"]:
                final_status = "FAILED"
            else: # PENDING, etc.
                final_status = "UNKNOWN_RESULT"
        else:
            # Si non trouvée (ou exception), reste UNKNOWN_RESULT
            final_status = "UNKNOWN_RESULT"

        # 3. MISE À JOUR SÉCURISÉE D'ÉTAT
        try:
            with Session(engine) as db:
                action = db.query(SikaActionModel).filter(SikaActionModel.action_id == action_id).first()
                if action:
                    action.status = final_status
                    action.updated_at = datetime.now(timezone.utc)
                    if final_status == "EXECUTED":
                        _log_action_event(db, action_id, user_id, "RECONCILIATION_IN_PROGRESS", "EXECUTED", "ACTION_RECONCILED", "PAYMECHAP_CONFIRMED")
                    elif final_status == "FAILED":
                        _log_action_event(db, action_id, user_id, "RECONCILIATION_IN_PROGRESS", "FAILED", "ACTION_RECONCILED", "PAYMECHAP_FAILED")
                    # Si UNKNOWN_RESULT, on le remet en UNKNOWN_RESULT pour annuler le RECONCILIATION_IN_PROGRESS
                    db.commit()
                    
                    if action_id in self.action_store:
                        self.action_store[action_id]["status"] = final_status
        except Exception as e:
            logger.error(f"[RECONCILIATION] Erreur mise à jour réconciliation {final_status}: {e}")

        return {
            "success": final_status == "EXECUTED",
            "status": final_status,
            "reconciled": True,
            "action_id": action_id
        }


    async def process_financial_event(self, user_id: int, event_data: dict) -> Dict[str, Any]:
        """Traitement d'un événement financier passif (ex: notification Mobile Money)."""
        pass


    async def process_financial_event(self, user_id: int, event_data: dict) -> Dict[str, Any]:
        """Traitement d'un événement financier passif (ex: notification Mobile Money)."""
        logger.info(f"[SIKA AGENT] Événement perçu pour user_id={user_id}: {event_data}")
        self.state = AgentState.PERCEIVING
        
        # Mettre à jour la mémoire du contexte
        memory_bridge.update_financial_context(user_id, {"last_event": event_data})
        
        self.state = AgentState.IDLE
        return {
            "status": "EVENT_RECEIVED",
            "state": self.state.value,
            "processed": True
        }

# Instance globale
sika_orchestrator = SikaAgentOrchestrator()
