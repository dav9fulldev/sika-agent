"""
PayMeChap Official Partner API v1 Integration
Intégration directe avec la plateforme Mobile Payment PayMeChap hébergée sur Render (https://gimwallet-api.onrender.com)
"""

import os
import logging
import requests
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta

logger = logging.getLogger("PayMeChapAPI")


class PayMeChapAPIService:
    """Service d'intégration partenaire directe avec l'API PayMeChap v1 sur Render."""

    def __init__(self):
        self.base_url = os.getenv("PAYMECHAP_API_URL", "https://gimwallet-api.onrender.com")
        self.client_id = os.getenv("PAYMECHAP_CLIENT_ID", "paymechap_partner")
        self.client_secret = os.getenv("PAYMECHAP_CLIENT_SECRET", "PaymeChap@2026#Secret")
        self.grant_type = "paymechap_credentials"
        self._cached_token: Optional[str] = None
        self._token_expires_at: Optional[datetime] = None

    def get_partner_access_token(self) -> Optional[str]:
        """Obtient un jeton OAuth2 partenaire depuis l'API PayMeChap (POST /api/v1/oauth/token).
        Optimisé avec retry et timeout adapté pour supporter l'offre gratuite Render (cold start).
        """
        if self._cached_token and self._token_expires_at and datetime.utcnow() < self._token_expires_at:
            return self._cached_token

        endpoint = f"{self.base_url}/api/v1/oauth/token"
        payload = {
            "grant_type": self.grant_type,
            "client_id": self.client_id,
            "client_secret": self.client_secret,
        }

        # Tentatives adaptées au Cold Start Render Free Tier (jusqu'à 2 essais avec 20s de timeout)
        for attempt in range(1, 3):
            try:
                logger.info(f"[PayMeChap OAuth] Demande de token OAuth2 partenaire vers {endpoint} (Essai {attempt})")
                resp = requests.post(
                    endpoint,
                    data=payload,
                    headers={"Content-Type": "application/x-www-form-urlencoded"},
                    timeout=150,
                )
                if resp.status_code in [200, 201]:
                    data = resp.json()
                    token = data.get("accessToken") or data.get("access_token") or data.get("token")
                    if token:
                        self._cached_token = token
                        self._token_expires_at = datetime.utcnow() + timedelta(hours=1)
                        logger.info("[PayMeChap OAuth] Token partenaire obtenu avec succès !")
                        return token
                logger.warning(f"[PayMeChap OAuth] Erreur réponse {resp.status_code}: {resp.text}")
            except Exception as e:
                logger.warning(f"[PayMeChap OAuth] Exception lors de la connexion à Render (Essai {attempt}): {e}")

        return None

    def initiate_otp_challenge(self, phone_number: str) -> Dict[str, Any]:
        """Déclenche la demande de code OTP SMS (POST /api/v1/auth/request-otp)."""
        clean_phone = phone_number.replace(" ", "").replace("+225", "")
        endpoint = f"{self.base_url}/api/v1/auth/request-otp"
        logger.info(f"[PayMeChap API] Demande d'OTP pour {clean_phone} via {endpoint}")

        try:
            resp = requests.post(
                endpoint,
                json={"telephone": clean_phone},
                headers={"Content-Type": "application/json"},
                timeout=150,
            )
            if resp.status_code in [200, 201]:
                data = {}
                try:
                    data = resp.json()
                except Exception:
                    pass
                return {
                    "success": True,
                    "provider": "PayMeChap",
                    "telephone": clean_phone,
                    "session_id": f"pmc_sess_{int(datetime.utcnow().timestamp())}",
                    "message": data.get("message") or f"📧 Code OTP PayMeChap envoyé par Email (Revo) au {phone_number} !",
                }
            else:
                err_data = {}
                try:
                    err_data = resp.json()
                except Exception:
                    pass
                err_text = resp.text.strip() if resp.text else ""
                err_msg = err_data.get("message") or err_data.get("detail") or err_data.get("error") or (err_text if err_text else f"Ce numéro ({clean_phone}) n'est pas enregistré sur PayMeChap.")
                logger.warning(f"[PayMeChap OTP] Échec {resp.status_code}: {err_msg}")
                return {
                    "success": False,
                    "status_code": resp.status_code,
                    "message": err_msg
                }
        except Exception as e:
            logger.warning(f"[PayMeChap OTP] Exception réseau: {e}")
            return {
                "success": False,
                "status_code": 503,
                "message": f"Erreur de connexion avec le serveur PayMeChap ({e})."
            }

    def verify_otp_code(self, phone_number: str, otp_code: str) -> Dict[str, Any]:
        """Vérifie le code OTP (POST /api/v1/auth/verify-otp)."""
        clean_phone = phone_number.replace(" ", "").replace("+225", "")
        endpoint = f"{self.base_url}/api/v1/auth/verify-otp"
        logger.info(f"[PayMeChap API] Vérification OTP {otp_code} pour {clean_phone}")

        try:
            resp = requests.post(
                endpoint,
                json={"telephone": clean_phone, "otp": otp_code},
                headers={"Content-Type": "application/json"},
                timeout=150,
            )
            if resp.status_code in [200, 201]:
                data = {}
                try:
                    data = resp.json()
                except Exception:
                    pass
                return {
                    "success": True,
                    "accessToken": data.get("accessToken") or data.get("token") or f"pmc_token_{clean_phone}",
                    "refreshToken": data.get("refreshToken"),
                    "message": data.get("message") or "✅ Code OTP vérifié avec succès sur PayMeChap API !",
                }
            else:
                err_data = {}
                try:
                    err_data = resp.json()
                except Exception:
                    pass
                err_text = resp.text.strip() if resp.text else ""
                err_msg = err_data.get("message") or err_data.get("detail") or err_data.get("error") or (err_text if err_text else "Code OTP incorrect ou expiré sur PayMeChap.")
                logger.warning(f"[PayMeChap Verify OTP] Échec {resp.status_code}: {err_msg}")
                return {
                    "success": False,
                    "status_code": resp.status_code,
                    "message": err_msg
                }
        except Exception as e:
            logger.warning(f"[PayMeChap Verify OTP] Exception: {e}")
            return {
                "success": False,
                "status_code": 503,
                "message": f"Erreur de connexion PayMeChap ({e})."
            }

    def verify_transaction_pin(self, phone_number: str, pin_code: str) -> Dict[str, Any]:
        """Vérifie le code PIN de transaction auprès de l'API PayMeChap (POST /api/v1/partners/wallets/{telephone}/verify-pin)."""
        clean_phone = phone_number.replace(" ", "").replace("+225", "")
        token = self.get_partner_access_token()
        endpoint = f"{self.base_url}/api/v1/partners/wallets/{clean_phone}/verify-pin"
        headers = {
            "Authorization": f"Bearer {token}" if token else "",
            "Content-Type": "application/json",
        }
        payload = {"pin": str(pin_code)}
        logger.info(f"[PayMeChap PIN API] Vérification PIN pour {clean_phone} via {endpoint}")

        try:
            resp = requests.post(endpoint, json=payload, headers=headers, timeout=150)
            if resp.status_code in [200, 201]:
                res_data = resp.json()
                stat = str(res_data.get("status", "")).upper()
                if stat in ["SUCCES", "SUCCESS", "VALID", "PROCESSED"] or res_data.get("success"):
                    logger.info(f"[PayMeChap PIN API] PIN validé avec succès pour {clean_phone}")
                    return {
                        "success": True,
                        "valid": True,
                        "message": res_data.get("message") or "✅ Code PIN PayMeChap validé avec succès !",
                        "data": res_data
                    }
            elif resp.status_code == 401:
                logger.warning(f"[PayMeChap PIN API] PIN incorrect ou non défini (HTTP 401) pour {clean_phone}")
                return {
                    "success": False,
                    "valid": False,
                    "message": "❌ Code PIN PayMeChap incorrect ou non défini (HTTP 401)."
                }
            logger.warning(f"[PayMeChap PIN API] Échec HTTP {resp.status_code}: {resp.text}")
        except Exception as e:
            logger.warning(f"[PayMeChap PIN API] Exception réseau sur {endpoint}: {e}")

        return {
            "success": False,
            "valid": False,
            "message": "❌ Impossible de vérifier le code PIN PayMeChap. Veuillez réessayer."
        }

    def fetch_live_balance(self, access_token: str, account_number: Optional[str] = None) -> Dict[str, Any]:
        """Consulte le solde en direct via les endpoints Partenaire Officiels (GET /api/v1/partners/wallets/{telephone}/balance)."""
        clean_phone = (account_number or "").replace(" ", "").replace("+225", "")
        partner_tok = self.get_partner_access_token()

        tokens_to_try = []
        if partner_tok:
            tokens_to_try.append(partner_tok)
        if access_token and not access_token.startswith("pmc_token_") and access_token not in tokens_to_try:
            tokens_to_try.append(access_token)

        # 1. Interroger l'endpoint partenaire officiel avec numéro de téléphone
        if clean_phone:
            for tok in tokens_to_try:
                headers = {"Authorization": f"Bearer {tok}"}
                partner_balance_ep = f"{self.base_url}/api/v1/partners/wallets/{clean_phone}/balance"
                try:
                    logger.info(f"[PayMeChap Partner API] GET {partner_balance_ep}")
                    resp = requests.get(partner_balance_ep, headers=headers, timeout=150)
                    logger.info(f"[PayMeChap Partner API] Balance status: {resp.status_code}, text: {resp.text}")
                    if resp.status_code == 200:
                        try:
                            raw_val = resp.json()
                            if isinstance(raw_val, (int, float)):
                                bal = float(raw_val)
                            elif isinstance(raw_val, str) and raw_val.replace('.', '', 1).isdigit():
                                bal = float(raw_val)
                            elif isinstance(raw_val, dict):
                                bal = float(raw_val.get("solde") or raw_val.get("balance") or 0.0)
                            else:
                                bal = float(resp.text.strip())

                            return {
                                "success": True,
                                "provider": "PayMeChap",
                                "account_number": account_number or clean_phone,
                                "balance": bal,
                                "currency": "XOF",
                                "last_synced_at": datetime.utcnow().isoformat(),
                            }
                        except Exception:
                            bal = float(resp.text.strip())
                            return {
                                "success": True,
                                "provider": "PayMeChap",
                                "account_number": account_number or clean_phone,
                                "balance": bal,
                                "currency": "XOF",
                                "last_synced_at": datetime.utcnow().isoformat(),
                            }
                except Exception as e:
                    logger.warning(f"[PayMeChap Partner Balance API] Exception on {partner_balance_ep}: {e}")

                # 2. Endpoint partenaire de détails de wallet: /api/v1/partners/wallets/{clean_phone}
                partner_info_ep = f"{self.base_url}/api/v1/partners/wallets/{clean_phone}"
                try:
                    logger.info(f"[PayMeChap Partner API] GET {partner_info_ep}")
                    resp = requests.get(partner_info_ep, headers=headers, timeout=150)
                    logger.info(f"[PayMeChap Partner API] Info status: {resp.status_code}, text: {resp.text}")
                    if resp.status_code == 200:
                        data = resp.json()
                        bal = float(data.get("solde") or data.get("balance") or 0.0)
                        return {
                            "success": True,
                            "provider": "PayMeChap",
                            "account_number": account_number or clean_phone,
                            "balance": bal,
                            "currency": data.get("devise") or data.get("currency") or "XOF",
                            "last_synced_at": datetime.utcnow().isoformat(),
                        }
                except Exception as e:
                    logger.warning(f"[PayMeChap Partner Info API] Exception on {partner_info_ep}: {e}")

        # 3. Fallbacks secondaires sur /wallets/balance & /wallets/me
        endpoints = [
            f"{self.base_url}/api/v1/wallets/balance",
            f"{self.base_url}/api/v1/wallets/me",
        ]
        for tok in tokens_to_try:
            headers = {"Authorization": f"Bearer {tok}"}
            for ep in endpoints:
                try:
                    resp = requests.get(ep, headers=headers, timeout=150)
                    if resp.status_code == 200:
                        data = resp.json()
                        w_data = data.get("data") if isinstance(data.get("data"), dict) else data
                        bal = float(w_data.get("solde") or w_data.get("balance") or w_data.get("soldePrincipal") or 0.0)
                        return {
                            "success": True,
                            "provider": "PayMeChap",
                            "account_number": account_number or clean_phone,
                            "balance": bal,
                            "currency": w_data.get("currency") or "XOF",
                            "last_synced_at": datetime.utcnow().isoformat(),
                        }
                except Exception:
                    pass

        return {
            "success": False,
            "provider": "PayMeChap",
            "account_number": account_number or clean_phone,
            "balance": 0.0,
            "currency": "XOF",
            "last_synced_at": datetime.utcnow().isoformat(),
        }

    def fetch_user_coffres(self, access_token: str, account_number: Optional[str] = None) -> List[Dict[str, Any]]:
        """Récupère la liste des Coffres-forts PayMeChap de l'utilisateur via l'API Partenaire (GET /api/v1/partners/wallets/{telephone}/coffres)."""
        tokens_to_try = []
        partner_tok = self.get_partner_access_token()
        if partner_tok:
            tokens_to_try.append(partner_tok)
        if access_token and access_token not in tokens_to_try:
            tokens_to_try.append(access_token)

        endpoints = []
        if account_number:
            clean_phone = account_number.replace(" ", "").replace("+225", "")
            endpoints.append(f"{self.base_url}/api/v1/partners/wallets/{clean_phone}/coffres")
        endpoints.append(f"{self.base_url}/api/v1/coffres")

        for tok in tokens_to_try:
            if not tok or tok.startswith("pmc_token_"):
                continue
            headers = {"Authorization": f"Bearer {tok}"}
            for ep in endpoints:
                try:
                    resp = requests.get(ep, headers=headers, timeout=150)
                    if resp.status_code == 200:
                        data = resp.json()
                        coffre_list = []
                        if isinstance(data, list):
                            coffre_list = data
                        elif isinstance(data, dict):
                            coffre_list = data.get("content") or data.get("data") or []
                        if coffre_list:
                            logger.info(f"[PayMeChap Coffres API] {len(coffre_list)} coffre(s) récupéré(s) depuis {ep}")
                            return coffre_list
                except Exception as e:
                    logger.warning(f"[PayMeChap Coffres API] Exception sur {ep}: {e}")

        return []

    def create_coffre(self, access_token: str, nom: str, type_coffre: str = "EPARGNE", objectif: float = 500000.0) -> Dict[str, Any]:
        """Crée un nouveau Coffre-fort sur l'API PayMeChap."""
        tok = access_token or self.get_partner_access_token()
        headers = {"Authorization": f"Bearer {tok}", "Content-Type": "application/json"}
        ep = f"{self.base_url}/api/v1/coffres"
        payload = {
            "nom": nom,
            "typeCoffre": type_coffre,
            "objectif": objectif
        }
        try:
            resp = requests.post(ep, json=payload, headers=headers, timeout=150)
            if resp.status_code in [200, 201]:
                return resp.json()
        except Exception as e:
            logger.warning(f"[PayMeChap Create Coffre API] Exception: {e}")
        return {"error": "FAILED_TO_CREATE_COFFRE"}

    def deposit_to_coffre(self, access_token: str, coffre_id: int, montant: float, account_number: Optional[str] = None) -> Dict[str, Any]:
        """Effectue un dépôt de fonds vers un Coffre-fort via l'API Partenaire (POST /api/v1/partners/wallets/{telephone}/coffres/{coffreId}/depot)."""
        tok = self.get_partner_access_token() or access_token
        headers = {"Authorization": f"Bearer {tok}", "Content-Type": "application/json"}

        endpoints = []
        if account_number:
            clean_phone = account_number.replace(" ", "").replace("+225", "")
            endpoints.append(f"{self.base_url}/api/v1/partners/wallets/{clean_phone}/coffres/{coffre_id}/depot")
        endpoints.append(f"{self.base_url}/api/v1/coffres/{coffre_id}/depot")

        payload = {"montant": montant}
        for ep in endpoints:
            try:
                resp = requests.post(ep, json=payload, headers=headers, timeout=150)
                if resp.status_code in [200, 201]:
                    return resp.json()
            except Exception as e:
                logger.warning(f"[PayMeChap Deposit Coffre API] Exception sur {ep}: {e}")
        return {"error": "FAILED_TO_DEPOSIT_COFFRE"}

    def categorize_transaction(self, tx_type: str, recipient: str, description: str, motif: str, amount: float) -> str:
        """Moteur d'Auto-Catégorisation Intelligente SIKA.
        Analyse le type, destinataire, description et motif pour classer la transaction dans l'une des catégories SIKA.
        """
        text = f"{recipient} {description} {motif}".lower()
        t_type = tx_type.lower()

        if any(kw in text for kw in ["carrefour", "supermarché", "supermarche", "restaurant", "repas", "boulangerie", "nourriture", "glovo", "food", "alimentation", "pain", "marché", "marche", "fastfood"]):
            return "Alimentation"
        elif any(kw in text for kw in ["yango", "uber", "vtc", "total", "totalenergies", "essence", "carburant", "péage", "peage", "transport", "bus", "express", "shell", "ola", "taxi"]):
            return "Transport"
        elif any(kw in text for kw in ["cinema", "cinéma", "majestic", "canal", "canal+", "netflix", "spotify", "loisir", "spectacle", "concert", "jeux", "divertissement"]):
            return "Loisirs"
        elif any(kw in text for kw in ["cie", "sodeci", "facture", "electricite", "électricité", "eau", "canalbox", "internet", "wifi", "mobile"]):
            return "Factures & Services"
        elif t_type in ["deposit", "recharge", "depot", "dépôt"] or "dépôt" in text or "rechargement" in text:
            return "Dépôt"
        elif t_type in ["transfer", "transfert", "virement"] or "transfert" in text:
            return "Transfert"
        else:
            return "Autres"

    def fetch_live_transactions(self, access_token: str, account_number: Optional[str] = None, limit: int = 20) -> List[Dict[str, Any]]:
        """Collecte l'historique des transactions depuis l'API PayMeChap et applique la catégorisation dynamique."""
        tokens_to_try = []
        partner_tok = self.get_partner_access_token()
        if partner_tok:
            tokens_to_try.append(partner_tok)
        if access_token and access_token not in tokens_to_try:
            tokens_to_try.append(access_token)

        endpoints = []
        if account_number:
            clean_phone = account_number.replace(" ", "").replace("+225", "")
            endpoints.append(f"{self.base_url}/api/v1/partners/wallets/{clean_phone}/transactions?page=0&size={limit}")
            endpoints.append(f"{self.base_url}/api/v1/partners/transactions/{clean_phone}")

        endpoints.extend([
            f"{self.base_url}/api/v1/transactions/recent",
            f"{self.base_url}/api/v1/transactions/me?page=0&size={limit}",
        ])

        for tok in tokens_to_try:
            if not tok or tok.startswith("pmc_token_"):
                continue
            headers = {"Authorization": f"Bearer {tok}"}
            for ep in endpoints:
                try:
                    resp = requests.get(ep, headers=headers, timeout=150)
                    if resp.status_code == 200:
                        data = resp.json()
                        raw_list = []
                        if isinstance(data, list):
                            raw_list = data
                        elif isinstance(data, dict):
                            raw_list = data.get("transactions") or data.get("content") or data.get("data") or []
                            if isinstance(raw_list, dict):
                                raw_list = [raw_list]

                        movements = []
                        for item in raw_list[:limit]:
                            raw_amt = float(item.get("montant") or item.get("amount") or 0.0)
                            tx_type_raw = str(item.get("type") or item.get("transactionType") or "TRANSFERT").upper()
                            counterparty_name = item.get("counterpartyName") or ""
                            counterparty_phone = item.get("counterpartyPhone") or ""
                            recip = counterparty_name or counterparty_phone or str(item.get("telephoneDestination") or item.get("recipient") or "PayMeChap")
                            desc = item.get("description") or item.get("message") or (f"Transfert vers {recip}" if tx_type_raw == "TRANSFERT" else "Mouvement PayMeChap")
                            motif = str(item.get("motif") or "")

                            category = self.categorize_transaction(tx_type_raw, recip, desc, motif, abs(raw_amt))
                            
                            is_deposit = tx_type_raw in ["RECEPTION", "DEPOT"] or "dépôt" in category.lower()

                            movements.append({
                                "id": str(item.get("id") or item.get("reference") or f"tx_pmc_{int(datetime.utcnow().timestamp())}"),
                                "wallet_provider": "PayMeChap",
                                "type": "deposit" if is_deposit else "payment",
                                "amount": abs(raw_amt),
                                "currency": item.get("devise") or item.get("currency") or "XOF",
                                "category": category,
                                "recipient": recip,
                                "description": desc,
                                "status": "COMPLETED" if str(item.get("status") or "").lower() in ["effectué", "completed", "success"] else "COMPLETED",
                                "timestamp": item.get("dateTransaction") or item.get("dateCreation") or item.get("created_at") or datetime.utcnow().isoformat(),
                            })

                        if movements:
                            logger.info(f"[PayMeChap Transactions] {len(movements)} transaction(s) réelles collectées et catégorisées depuis {ep}")
                            return movements
                except Exception as e:
                    logger.warning(f"[PayMeChap Transactions API] Exception sur {ep}: {e}")

        return []

    def execute_payout(self, access_token: str, recipient_phone: str, amount: float, motif: str = "Transfert SIKA", action_id: Optional[str] = None) -> Dict[str, Any]:
        """Exécute un transfert de fonds PayMeChap via l'API Partenaire (POST /api/v1/partners/transactions/{sender_phone}/transfer)."""
        token = self.get_partner_access_token() or access_token
        clean_recipient = recipient_phone.replace(" ", "").replace("+225", "")
        endpoint = f"{self.base_url}/api/v1/partners/transactions/{clean_recipient}/transfer"

        full_motif = f"{motif} [{action_id}]" if action_id else motif
        payload = {
            "telephoneDestination": clean_recipient,
            "montant": amount,
            "motif": full_motif,
            "reference": action_id or f"PARTNER-SIKA-{int(datetime.utcnow().timestamp())}",
            "idempotency_key": action_id,
        }

        try:
            headers = {
                "Authorization": f"Bearer {token}" if token else "",
                "Content-Type": "application/json",
            }
            if action_id:
                headers["X-Idempotency-Key"] = action_id

            logger.info(f"[PayMeChap Payout API] POST {endpoint} pour {amount} FCFA vers {clean_recipient} (action_id={action_id})")
            resp = requests.post(endpoint, json=payload, headers=headers, timeout=150)
            if resp.status_code in [200, 201]:
                data = resp.json()
                res_data = data.get("data") or data
                return {
                    "success": True,
                    "transaction_id": res_data.get("transaction_id") or action_id or f"TRANSFER-{int(datetime.utcnow().timestamp())}",
                    "reference": action_id or res_data.get("reference") or f"PARTNER-SIKA-{int(datetime.utcnow().timestamp())}",
                    "amount": float(res_data.get("amount") or amount),
                    "fees": float(res_data.get("fees") or 0.0),
                    "currency": res_data.get("currency") or "XOF",
                    "status": (res_data.get("status") or "COMPLETED").lower(),
                    "created_at": res_data.get("created_at") or datetime.utcnow().isoformat(),
                }
            logger.warning(f"[PayMeChap Payout API] Échec HTTP {resp.status_code}: {resp.text}")
        except Exception as e:
            logger.warning(f"[PayMeChap Payout API] Exception réseau sur {endpoint}: {e}")

        return {
            "success": False,
            "status": "TEMPORARILY_UNAVAILABLE",
            "message": "Je n'arrive pas à joindre PayMeChap pour le moment. Aucun transfert n'a été effectué.",
        }



paymechap_api_service = PayMeChapAPIService()
