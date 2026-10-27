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
        if not value or (field == "full_name" and value in ("David YAO", "Utilisateur Google", "User")):
            missing.append(field)
    return missing


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
