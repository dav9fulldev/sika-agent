"""
SIKA Perception Engine — Méthode 3 (Analyse & Interception SMS + Notifications Push Android)
Analyse en temps réel des SMS de transactions Wave, Orange Money, MTN MoMo, Moov Money et Banques.
"""

import re
import logging
from typing import Dict, Any, Optional
from datetime import datetime

logger = logging.getLogger("SikaPerception")


class SikaPerceptionService:
    """Moteur de perception intelligente SIKA (Méthode 3).

    Analyse par Regex & NLP des notifications Push et SMS de télécoms pour extraire instantanément
    le montant, le type de mouvement (Dépôt, Retrait, Transfert, Paiement) et le nouveau solde.
    """

    def parse_notification(self, text: str, sender: Optional[str] = None) -> Dict[str, Any]:
        """Analyse le texte brut d'un SMS ou d'une notification et extrait les données financières structurées."""
        raw_text = text.strip()
        text_lower = raw_text.lower()
        sender_clean = (sender or "").upper()

        provider = "Autre"
        if "wave" in text_lower or "WAVE" in sender_clean:
            provider = "Wave"
        elif "orange" in text_lower or "OM" in sender_clean or "ORANGE" in sender_clean:
            provider = "Orange Money"
        elif "mtn" in text_lower or "MOMO" in sender_clean or "MTN" in sender_clean:
            provider = "MTN MoMo"
        elif "moov" in text_lower or "MOOV" in sender_clean:
            provider = "Moov Money"

        # 1. Extraction du Montant principal
        # Ex: "15 000 FCFA", "15000 FCFA", "4,500 FCFA", "7000 XOF", "$25.00"
        amount = 0.0
        amount_match = re.search(r'(\d+[\d\s\.,]*)\s*(FCFA|XOF|\$|€|FCFA)', raw_text, re.IGNORECASE)
        if amount_match:
            raw_amt = amount_match.group(1).replace(" ", "").replace(",", "")
            try:
                amount = float(raw_amt)
            except ValueError:
                amount = 0.0

        # 2. Extraction du Nouveau Solde
        # Ex: "Solde: 45 000 FCFA", "Nouveau solde: 22 000", "Solde actuel est 8000 FCFA"
        new_balance = None
        balance_match = re.search(r'(?:solde|nouveau solde|solde actuel|balance)[^\d]*(\d+[\d\s\.,]*)', raw_text, re.IGNORECASE)
        if balance_match:
            raw_bal = balance_match.group(1).replace(" ", "").replace(",", "")
            try:
                new_balance = float(raw_bal)
            except ValueError:
                new_balance = None

        # 3. Détermination du type de mouvement (deposit, payment, transfer, withdrawal)
        tx_type = "payment"
        if any(kw in text_lower for kw in ["reçu", "recu", "rechargement", "dépôt", "depot", "received", "credited"]):
            tx_type = "deposit"
        elif any(kw in text_lower for kw in ["transfert", "transférer", "transfere", "envoyé", "envoye", "sent"]):
            tx_type = "transfer"
        elif any(kw in text_lower for kw in ["retrait", "withdrawn"]):
            tx_type = "withdrawal"

        # 4. Extraction du destinataire ou de l'expéditeur
        recipient = ""
        recipient_match = re.search(r'(?:de|vers|à|a|recipient)\s+([A-ZÀ-ÿ0-9\s]+?)(?=\.|\,|solde|ref|$)', raw_text, re.IGNORECASE)
        if recipient_match:
            recipient = recipient_match.group(1).strip()

        logger.info(f"[SIKA PERCEPTION] Interception SMS/Push réussi: {provider} | {tx_type} | {amount} XOF | Solde: {new_balance}")

        return {
            "success": True,
            "method": "PERCEPTION_ENGINE_SMS_PUSH",
            "provider": provider,
            "type": tx_type,
            "amount": amount,
            "currency": "XOF",
            "new_balance": new_balance,
            "recipient_or_sender": recipient or provider,
            "raw_text": raw_text,
            "timestamp": datetime.utcnow().isoformat()
        }


sika_perception_service = SikaPerceptionService()
