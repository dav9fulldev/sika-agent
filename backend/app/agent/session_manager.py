import json
import logging
from typing import Dict, Any
from datetime import datetime
from sqlalchemy.orm import Session
from ..database import engine
from ..models.sika_session import SikaSessionModel

logger = logging.getLogger(__name__)

class SikaSessionManager:
    def __init__(self):
        self.user_sessions: Dict[str, Any] = {}

    def reset_all_sessions(self):
        """Réinitialise toutes les sessions conversationnelles multi-tours."""
        self.user_sessions.clear()
        logger.info("[SIKA SESSION MANAGER] Toutes les sessions utilisateur ont été réinitialisées.")

    def get_user_session(self, user_id: str = "1") -> Dict[str, Any]:
        """Récupère ou crée la session conversationnelle multi-tours."""
        str_uid = str(user_id)
        if str_uid not in self.user_sessions:
            restored = False
            try:
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

    def save_user_session(self, user_id: str, session_data: Dict[str, Any] = None):
        """Sauvegarde l'état conversationnel dans la base de données."""
        str_uid = str(user_id)
        
        if session_data:
            self.user_sessions[str_uid] = session_data
            
        sess = self.user_sessions.get(str_uid)
        if not sess:
            return
            
        try:
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

sika_session_manager = SikaSessionManager()
