"""
Wallet Tools pour l'Agent SIKA

Consultation des portefeuilles (Wave, Orange Money, MTN), soldes et contacts.
"""

from typing import Dict, Any, List, Optional
from ...config import settings
from .tool_models import RiskLevel, ToolResult

from ...repositories.financial_repository import financial_repository
from ...services.wallet_integrations.paymechap_api_service import paymechap_api_service
from ...services.wallet_integrations.wave_api_service import wave_api_service
from ...services.wallet_integrations.orange_money_api_service import orange_money_api_service
from ...services.wallet_integrations.mtn_momo_api_service import mtn_momo_api_service

def get_wallets(user_id: Optional[str] = None) -> ToolResult:
    """Retourne la liste des wallets connus de l'utilisateur.

    Priorité : base de données (financial_repository) -> services live.
    Les MOCK_WALLETS ne sont utilisés qu'en environnement non-production.
    """
    # Attempt to load real wallets from repository when possible
    try:
        repo_wallets = financial_repository.get_wallets(user_id)
    except Exception:
        repo_wallets = []

    user_wallets: List[Dict[str, Any]] = []
    if repo_wallets:
        for w in repo_wallets:
            prov = (w.get("provider") or "").lower()
            acc = w.get("external_wallet_id")
            w_dict = {
                "id": w.get("id") or f"w_{acc}",
                "user_id": str(user_id) if user_id is not None else "",
                "provider": w.get("provider"),
                "account_number": acc,
                "auth_method": "PAYMECHAP_PARTNER_API" if "paymechap" in prov else "OAUTH2_API",
                "is_active": True,
                "balance": 0.0,
                "currency": "XOF",
            }
            if "paymechap" in prov:
                fetched = paymechap_api_service.fetch_live_balance("", acc)
                w_dict["balance"] = float(fetched.get("balance", 0.0))
                w_dict["currency"] = fetched.get("currency", "XOF")
            elif "wave" in prov:
                fetched = wave_api_service.fetch_live_balance("token", acc)
                w_dict["balance"] = float(fetched.get("balance", 0.0))
            elif "orange" in prov:
                fetched = orange_money_api_service.fetch_live_balance("token", acc)
                w_dict["balance"] = float(fetched.get("balance", 0.0))
            elif "mtn" in prov:
                fetched = mtn_momo_api_service.fetch_live_balance("token", acc)
                w_dict["balance"] = float(fetched.get("balance", 0.0))

            user_wallets.append(w_dict)

        return ToolResult(
            success=True,
            tool_name="get_wallets",
            risk_level=RiskLevel.READ_ONLY,
            data={
                "user_id": user_id,
                "wallets": user_wallets
            }
        )

    # Production: no wallets found, return empty list
    return ToolResult(
        success=True,
        tool_name="get_wallets",
        risk_level=RiskLevel.READ_ONLY,
        data={
            "user_id": user_id,
            "wallets": []
        }
    )

    # Production and no enrolled wallets found -> return empty list (agent should use /wallets/me context)
    return ToolResult(
        success=True,
        tool_name="get_wallets",
        risk_level=RiskLevel.READ_ONLY,
        data={
            "user_id": user_id,
            "wallets": []
        }
    )

def get_wallet_balance(provider: str, user_id: Optional[str] = None) -> ToolResult:
    """Retourne le solde d'un wallet spécifique pour l'utilisateur si possible.

    Favorise les portefeuilles enrôlés en base; n'expose pas les mocks en production.
    """
    clean_provider = provider.lower().strip()

    try:
        repo_wallets = financial_repository.get_wallets(user_id)
    except Exception:
        repo_wallets = []

    # Try find in repo wallets
    found = None
    for w in repo_wallets:
        if clean_provider in (w.get("provider") or "").lower():
            found = w
            break

    if found:
        prov = (found.get("provider") or "").lower()
        acc = found.get("external_wallet_id")
        if "paymechap" in prov:
            fetched = paymechap_api_service.fetch_live_balance("", acc)
            return ToolResult(success=True, tool_name="get_wallet_balance", risk_level=RiskLevel.READ_ONLY, data={"provider": found.get("provider"), "balance": float(fetched.get("balance", 0.0)), "currency": fetched.get("currency", "XOF")})
        if "wave" in prov:
            fetched = wave_api_service.fetch_live_balance("token", acc)
            return ToolResult(success=True, tool_name="get_wallet_balance", risk_level=RiskLevel.READ_ONLY, data={"provider": found.get("provider"), "balance": float(fetched.get("balance", 0.0)), "currency": "XOF"})
        if "orange" in prov:
            fetched = orange_money_api_service.fetch_live_balance("token", acc)
            return ToolResult(success=True, tool_name="get_wallet_balance", risk_level=RiskLevel.READ_ONLY, data={"provider": found.get("provider"), "balance": float(fetched.get("balance", 0.0)), "currency": "XOF"})
        if "mtn" in prov:
            fetched = mtn_momo_api_service.fetch_live_balance("token", acc)
            return ToolResult(success=True, tool_name="get_wallet_balance", risk_level=RiskLevel.READ_ONLY, data={"provider": found.get("provider"), "balance": float(fetched.get("balance", 0.0)), "currency": "XOF"})

    # No repo wallet found
    return ToolResult(
        success=False,
        tool_name="get_wallet_balance",
        risk_level=RiskLevel.READ_ONLY,
        data={},
        error_message=f"Wallet '{provider}' non trouvé pour l'utilisateur."
    )

def get_total_balance(user_id: Optional[str] = None) -> ToolResult:
    """Calcule le montant total disponible sur tous les wallets de l'utilisateur.

    Utilise la base et les services live; n'expose pas les mocks en production.
    """
    try:
        repo_wallets = financial_repository.get_wallets(user_id)
    except Exception:
        repo_wallets = []

    total = 0.0
    wallets = []
    if repo_wallets:
        for w in repo_wallets:
            prov = (w.get("provider") or "").lower()
            acc = w.get("external_wallet_id")
            bal = 0.0
            if "paymechap" in prov:
                fetched = paymechap_api_service.fetch_live_balance("", acc)
                bal = float(fetched.get("balance", 0.0))
            elif "wave" in prov:
                fetched = wave_api_service.fetch_live_balance("token", acc)
                bal = float(fetched.get("balance", 0.0))
            elif "orange" in prov:
                fetched = orange_money_api_service.fetch_live_balance("token", acc)
                bal = float(fetched.get("balance", 0.0))
            elif "mtn" in prov:
                fetched = mtn_momo_api_service.fetch_live_balance("token", acc)
                bal = float(fetched.get("balance", 0.0))
            total += bal
            wallets.append({"provider": w.get("provider"), "balance": bal, "currency": "XOF"})

        return ToolResult(success=True, tool_name="get_total_balance", risk_level=RiskLevel.READ_ONLY, data={"user_id": user_id, "total_balance": total, "currency": "XOF", "wallet_count": len(wallets), "wallets": wallets})

    # fallback to mocks only outside production
    if getattr(settings, 'ENV', 'development') != 'production':
        # Production: no wallets, total balance 0
        return ToolResult(success=True, tool_name="get_total_balance", risk_level=RiskLevel.READ_ONLY, data={"user_id": user_id, "total_balance": 0.0, "currency": "XOF", "wallet_count": 0})

    return ToolResult(success=True, tool_name="get_total_balance", risk_level=RiskLevel.READ_ONLY, data={"user_id": user_id, "total_balance": 0.0, "currency": "XOF", "wallet_count": 0})

def search_contact(query: str) -> ToolResult:
    """Recherche un destinataire parmi les contacts connus."""
    clean_query = query.lower().strip()
    # No mock contacts in production; return empty list
    return ToolResult(
        success=True,
        tool_name="search_contact",
        risk_level=RiskLevel.READ_ONLY,
        data={
            "query": query,
            "contacts": [],
            "count": 0
        }
    )
