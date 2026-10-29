"""
État du profil utilisateur SIKA Pay : champs manquants et statut d'identité (KYC).

Règle produit :
- Un profil est complet quand le nom et le pays sont connus (l'email est toujours présent).
- Une identité n'est « vérifiée » que si PayPal confirme côté serveur que le compte est vérifié
  (kyc_status = "paypal"). Une soumission dans l'application reste « en attente » (submitted).
"""

from typing import Dict, Any, List

REQUIRED_PROFILE_FIELDS = ("full_name", "country")


def missing_profile_fields(user) -> List[str]:
    missing = []
    for field in REQUIRED_PROFILE_FIELDS:
        value = (getattr(user, field, None) or "").strip()
        if not value or (field == "full_name" and value in PLACEHOLDER_NAMES):
            missing.append(field)
    return missing


PLACEHOLDER_NAMES = ("David YAO", "Utilisateur Google", "User")


def first_name(user) -> str:
    """Prénom affichable du compte (vide si le nom est absent ou provisoire)."""
    full = (getattr(user, "full_name", None) or "").strip()
    if not full or full in PLACEHOLDER_NAMES:
        return ""
    return full.split()[0][:40]


def account_first_name(user_id) -> str:
    """Prénom de l'utilisateur authentifié, lu en base : jamais celui envoyé par le client."""
    try:
        from sqlalchemy.orm import Session
        from ..database import engine
        from ..models.user import UserModel
        with Session(engine) as db:
            user = db.get(UserModel, int(user_id))
            return first_name(user) if user else ""
    except (TypeError, ValueError, Exception):
        return ""


def profile_status(user) -> Dict[str, Any]:
    kyc_status = getattr(user, "kyc_status", None) or "none"
    missing = missing_profile_fields(user)
    return {
        "missing_fields": missing,
        "complete": not missing,
        "kyc_status": kyc_status,
        "kyc_verified": kyc_status == "paypal",
        "kyc_source": "paypal" if kyc_status == "paypal" else None,
        "paypal_linked": bool(getattr(user, "paypal_payer_id", None)),
    }
