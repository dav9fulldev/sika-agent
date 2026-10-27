"""
SIKA Pay — Service métier des checkouts PayPal (sandbox).

Responsabilités (côté serveur uniquement) :
1. Préparer un checkout à partir d'un SKU du catalogue : le prix, la devise et le total
   sont calculés ici, jamais fournis par le modèle IA ni par le client mobile.
2. Vérifier le budget exprimé par l'utilisateur, les plafonds et les devises autorisées.
3. Lier la confirmation utilisateur à une empreinte (details_hash) des détails affichés.
4. Créer la commande PayPal uniquement après cette confirmation explicite.
5. Vérifier auprès de PayPal (GET order) que la commande est APPROVED avant toute capture.
6. Capturer avec un PayPal-Request-Id stable (pas de double capture en cas de répétition).
7. Vérifier le montant et le statut réellement capturés, puis journaliser chaque transition.
"""

import json
import hmac
import uuid
import hashlib
import logging
from datetime import datetime, timezone, timedelta
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from typing import Dict, Any, Optional, List
from urllib.parse import urlparse

from sqlalchemy.orm import Session

from ..config import settings
from ..database import engine
from ..models.paypal_checkout import PayPalCheckoutModel, TERMINAL_STATUSES
from ..models.sika_action_event import SikaActionEventModel
from . import demo_catalog
from .wallet_integrations.paypal_api_service import (
    paypal_api_service,
    PayPalAPIError,
    PayPalNetworkError,
    PayPalConfigurationError,
)

logger = logging.getLogger("SikaPayPalCheckout")

MAX_QUANTITY = 10
CENT = Decimal("0.01")

STATUS_LABELS = {
    "AWAITING_USER_CONFIRMATION": "Prepared by SIKA — waiting for your confirmation",
    "CREATING_ORDER": "Creating the PayPal order",
    "AWAITING_PAYPAL_APPROVAL": "PayPal order created — waiting for your approval on PayPal",
    "APPROVED": "Approved on PayPal — ready to complete the payment",
    "CAPTURING": "Completing the payment with PayPal",
    "COMPLETED": "Payment captured by PayPal",
    "PENDING": "Capture pending at PayPal",
    "DECLINED": "Payment declined by PayPal",
    "CANCELLED": "Cancelled — no payment was made",
    "EXPIRED": "Expired — no payment was made",
    "FAILED": "Failed — no payment was captured",
    "UNKNOWN_RESULT": "Result unknown — verify with PayPal before any retry",
}

NEXT_ACTIONS = {
    "AWAITING_USER_CONFIRMATION": "CONFIRM",
    "AWAITING_PAYPAL_APPROVAL": "APPROVE_ON_PAYPAL",
    "APPROVED": "CAPTURE",
    "UNKNOWN_RESULT": "VERIFY",
    "PENDING": "VERIFY",
}

# Erreurs PayPal à la capture (https://developer.paypal.com/api/handle-payment-failures) :
# le payeur doit repasser sur PayPal pour choisir un autre moyen de paiement (le lien d'approbation reste valable)…
PAYER_MUST_REAPPROVE = {
    "INSTRUMENT_DECLINED": "The payment method was declined. Choose another one on PayPal.",
    "REDIRECT_PAYER_FOR_ALTERNATE_FUNDING": "PayPal asks you to choose another payment method.",
    "PAYER_ACTION_REQUIRED": "PayPal needs one more action from you. Open PayPal to continue.",
    "ORDER_NOT_APPROVED": "The order is not approved yet. Approve it on PayPal.",
}
# … ou le paiement est refusé et ne peut pas aboutir avec ce compte : aucune nouvelle tentative automatique.
PAYMENT_REFUSED = {
    "PAYER_CANNOT_PAY": "PayPal cannot accept a payment from this account (funds, limits or verification). Try another PayPal account.",
    "TRANSACTION_REFUSED": "PayPal refused this transaction. Check your PayPal account or try another payment method.",
    "MAX_NUMBER_OF_PAYMENT_ATTEMPTS_EXCEEDED": "Too many payment attempts. Use another payment method or contact PayPal.",
    "PAYMENT_DENIED": "PayPal denied this payment. Use another payment method.",
    "INVALID_ACCOUNT_STATUS": "Your PayPal account cannot pay right now (for example locked). Contact PayPal.",
    "CANNOT_PAY_SELF": "The payer and the merchant are the same PayPal account. Pay with a different buyer account.",
    "PAYEE_ACCOUNT_RESTRICTED": "The merchant's PayPal account cannot receive payments right now.",
    "COMPLIANCE_VIOLATION": "PayPal blocked this payment for compliance reasons.",
    "CURRENCY_NOT_SUPPORTED": "PayPal does not support this currency for this account.",
    "UNSUPPORTED_PAYEE_CURRENCY": "The merchant account does not accept this currency.",
}


def paypal_error_message(issue: str, fallback: str) -> str:
    return PAYER_MUST_REAPPROVE.get(issue) or PAYMENT_REFUSED.get(issue) or fallback


class CheckoutError(Exception):
    """Erreur métier explicite renvoyée à l'agent et au client mobile."""

    def __init__(self, code: str, message: str, http_status: int = 400, data: Optional[Dict[str, Any]] = None):
        self.code = code
        self.message = message
        self.http_status = http_status
        self.data = data or {}
        super().__init__(f"{code}: {message}")

    def to_dict(self) -> Dict[str, Any]:
        return {"success": False, "error_code": self.code, "message": self.message, **self.data}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _utc(dt: Optional[datetime]) -> Optional[datetime]:
    if dt is not None and dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def _money(value: Any, field: str) -> Decimal:
    if isinstance(value, bool):
        raise CheckoutError("INVALID_AMOUNT", f"{field} must be a number.")
    try:
        dec = Decimal(str(value))
    except (InvalidOperation, ValueError, TypeError):
        raise CheckoutError("INVALID_AMOUNT", f"{field} must be a number.")
    if not dec.is_finite() or dec <= 0:
        raise CheckoutError("INVALID_AMOUNT", f"{field} must be a positive amount.")
    return dec.quantize(CENT, rounding=ROUND_HALF_UP)


def _fmt(dec: Decimal) -> str:
    return str(dec.quantize(CENT, rounding=ROUND_HALF_UP))


def _compute_details_hash(row: PayPalCheckoutModel) -> str:
    canonical = json.dumps(
        {
            "checkout_id": row.checkout_id,
            "user_id": int(row.user_id),
            "sku": row.sku,
            "quantity": int(row.quantity),
            "unit_amount": row.unit_amount,
            "total_amount": row.total_amount,
            "currency": row.currency,
            "merchant": row.merchant_name,
        },
        sort_keys=True,
        separators=(",", ":"),
    )
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def _log_event(db: Session, row: PayPalCheckoutModel, previous: Optional[str], new: str, event_type: str,
               reason: Optional[str] = None, metadata: Optional[dict] = None):
    db.add(SikaActionEventModel(
        action_id=row.checkout_id,
        user_id=int(row.user_id),
        previous_status=previous,
        new_status=new,
        event_type=event_type,
        reason=reason,
        metadata_json=json.dumps(metadata) if metadata else None,
        created_at=_now(),
    ))


def _is_paypal_url(url: Optional[str]) -> bool:
    if not url:
        return False
    parsed = urlparse(url)
    host = (parsed.hostname or "").lower()
    return parsed.scheme == "https" and (host == "paypal.com" or host.endswith(".paypal.com"))


class PayPalCheckoutService:
    """Orchestration sécurisée du flux Orders v2 : préparer → confirmer → approuver → capturer → vérifier."""

    def __init__(self, api=None):
        self.api = api or paypal_api_service

    # ==================================================================
    # Lecture
    # ==================================================================

    def to_public_dict(self, row: PayPalCheckoutModel, events: Optional[List[Dict[str, Any]]] = None) -> Dict[str, Any]:
        within_budget = None
        remaining = None
        if row.budget_limit:
            within_budget = Decimal(row.total_amount) <= Decimal(row.budget_limit)
            remaining = _fmt(Decimal(row.budget_limit) - Decimal(row.total_amount))

        verified = [
            f"Unit price {row.unit_amount} {row.currency} from the {row.merchant_name} catalog (server-side)",
            f"Total {row.total_amount} {row.currency} computed by the SIKA backend",
        ]
        if row.paypal_order_id:
            verified.append(f"PayPal order {row.paypal_order_id} status {row.paypal_order_status} (returned by PayPal)")
        if row.capture_id:
            verified.append(
                f"PayPal capture {row.capture_id} status {row.capture_status} for "
                f"{row.captured_amount} {row.captured_currency} (returned by PayPal)"
            )

        user_provided = [f"Quantity: {row.quantity}"]
        if row.budget_limit:
            user_provided.append(f"Budget limit: {row.budget_limit} {row.budget_currency}")

        data = {
            "checkout_id": row.checkout_id,
            "type": "paypal_checkout",
            "provider": "PAYPAL",
            "environment": "sandbox",
            "status": row.status,
            "status_label": STATUS_LABELS.get(row.status, row.status),
            "next_action": NEXT_ACTIONS.get(row.status),
            "is_terminal": row.status in TERMINAL_STATUSES,
            "merchant": {"name": row.merchant_name, "is_demo": True, "catalog_source": demo_catalog.CATALOG_SOURCE},
            "item": {"sku": row.sku, "name": row.item_name, "description": row.item_description, "delivery": "digital"},
            "quantity": row.quantity,
            "unit_amount": row.unit_amount,
            "total_amount": row.total_amount,
            "currency": row.currency,
            "fees": {"known_fees": "0.00", "note": "No SIKA fee. PayPal does not charge buyers for a standard checkout."},
            "budget": {
                "limit": row.budget_limit,
                "currency": row.budget_currency,
                "within_budget": within_budget,
                "remaining_after_purchase": remaining,
            },
            "details_hash": row.details_hash,
            "confirmed_by": row.confirmed_by,
            "paypal": {
                "order_id": row.paypal_order_id,
                "order_status": row.paypal_order_status,
                "approve_url": row.approve_url if row.status == "AWAITING_PAYPAL_APPROVAL" else None,
                "capture_id": row.capture_id,
                "capture_status": row.capture_status,
                "captured_amount": row.captured_amount,
                "captured_currency": row.captured_currency,
                "debug_id": row.paypal_debug_id,
            },
            "provenance": {
                "verified": verified,
                "user_provided": user_provided,
                "assumptions": [
                    "Digital product, no shipping.",
                    "Demo merchant and fictional catalog; PayPal operations are real calls to PayPal's test environment.",
                ],
            },
            "last_error": {"code": row.last_error_code, "message": row.last_error_message} if row.last_error_code else None,
            "expires_at": _utc(row.expires_at).isoformat() if row.expires_at else None,
            "created_at": _utc(row.created_at).isoformat() if row.created_at else None,
            "updated_at": _utc(row.updated_at).isoformat() if row.updated_at else None,
        }
        if events is not None:
            data["events"] = events
        return data

    def _load_owned(self, db: Session, user_id: int, checkout_id: str) -> PayPalCheckoutModel:
        row = db.query(PayPalCheckoutModel).filter(PayPalCheckoutModel.checkout_id == str(checkout_id)).first()
        if not row:
            raise CheckoutError("NOT_FOUND", "Checkout not found.", 404)
        if str(row.user_id) != str(user_id):
            logger.warning(f"[SECURITY REJECT] User {user_id} tried to access checkout {checkout_id} of another user.")
            raise CheckoutError("FORBIDDEN", "This checkout does not belong to the current user.", 403)
        return row

    def _events(self, db: Session, checkout_id: str) -> List[Dict[str, Any]]:
        rows = db.query(SikaActionEventModel).filter(
            SikaActionEventModel.action_id == checkout_id
        ).order_by(SikaActionEventModel.id.asc()).all()
        return [
            {
                "event_type": e.event_type,
                "previous_status": e.previous_status,
                "new_status": e.new_status,
                "reason": e.reason,
                "created_at": _utc(e.created_at).isoformat() if e.created_at else None,
            }
            for e in rows
        ]

    def get_checkout(self, user_id: int, checkout_id: str, sync: bool = False) -> Dict[str, Any]:
        if sync:
            return self.sync_with_paypal(user_id, checkout_id)
        with Session(engine) as db:
            row = self._load_owned(db, user_id, checkout_id)
            if self._expire_if_needed(db, row):
                db.commit()
            return self.to_public_dict(row, events=self._events(db, row.checkout_id))

    def list_checkouts(self, user_id: int, limit: int = 10) -> List[Dict[str, Any]]:
        limit = max(1, min(int(limit or 10), 50))
        with Session(engine) as db:
            rows = db.query(PayPalCheckoutModel).filter(
                PayPalCheckoutModel.user_id == user_id
            ).order_by(PayPalCheckoutModel.created_at.desc()).limit(limit).all()
            return [self.to_public_dict(r) for r in rows]

    # ==================================================================
    # Étape 1 — Préparation (aucun appel PayPal, aucun mouvement d'argent)
    # ==================================================================

    def prepare_checkout(self, user_id: int, sku: str, quantity: Any = 1, budget_limit: Any = None,
                         budget_currency: Optional[str] = None, user_request: Optional[str] = None) -> Dict[str, Any]:
        product = demo_catalog.get_product(sku)
        if not product:
            raise CheckoutError("UNKNOWN_PRODUCT", f"No product with SKU '{sku}' exists in the demo catalog.", 404)

        if isinstance(quantity, bool):
            raise CheckoutError("INVALID_QUANTITY", "Quantity must be a whole number.")
        try:
            qty_dec = Decimal(str(quantity))
        except (InvalidOperation, ValueError, TypeError):
            raise CheckoutError("INVALID_QUANTITY", "Quantity must be a whole number.")
        if not qty_dec.is_finite() or qty_dec != qty_dec.to_integral_value() or not (1 <= qty_dec <= MAX_QUANTITY):
            raise CheckoutError("INVALID_QUANTITY", f"Quantity must be a whole number between 1 and {MAX_QUANTITY}.")
        qty = int(qty_dec)

        currency = product["currency"].upper()
        if currency not in settings.PAYPAL_ALLOWED_CURRENCIES:
            raise CheckoutError("CURRENCY_NOT_ALLOWED", f"Currency {currency} is not enabled for SIKA Pay.")

        unit = _money(product["unit_price"], "unit price")
        total = (unit * qty).quantize(CENT, rounding=ROUND_HALF_UP)
        max_amount = Decimal(str(settings.PAYPAL_MAX_ORDER_AMOUNT)).quantize(CENT)
        if total > max_amount:
            raise CheckoutError(
                "AMOUNT_ABOVE_LIMIT",
                f"Total {_fmt(total)} {currency} exceeds the SIKA Pay limit of {_fmt(max_amount)} {currency}.",
            )

        budget_dec = None
        budget_cur = None
        if budget_limit not in (None, "", 0, "0"):
            budget_dec = _money(budget_limit, "budget limit")
            budget_cur = (budget_currency or currency).strip().upper()
            if budget_cur != currency:
                raise CheckoutError(
                    "BUDGET_CURRENCY_MISMATCH",
                    f"The budget is in {budget_cur} but the product is priced in {currency}. "
                    f"SIKA never converts currencies on its own: please give the budget in {currency}.",
                )
            if total > budget_dec:
                alternatives = [
                    p for p in demo_catalog.search_products(product["name"], max_price=budget_dec, limit=3)
                    if p["sku"] != product["sku"]
                ] or demo_catalog.search_products("", max_price=budget_dec, limit=3)
                raise CheckoutError(
                    "OVER_BUDGET",
                    f"{product['name']} costs {_fmt(total)} {currency}, above your budget of {_fmt(budget_dec)} {currency}.",
                    data={
                        "total_amount": _fmt(total),
                        "budget_limit": _fmt(budget_dec),
                        "currency": currency,
                        "alternatives_within_budget": alternatives,
                    },
                )

        now = _now()
        with Session(engine) as db:
            # Une nouvelle préparation invalide toute confirmation précédente encore en attente
            stale = db.query(PayPalCheckoutModel).filter(
                PayPalCheckoutModel.user_id == user_id,
                PayPalCheckoutModel.status == "AWAITING_USER_CONFIRMATION",
            ).all()
            for old in stale:
                old.status = "CANCELLED"
                old.last_error_code = "REPLACED_BY_NEW_REQUEST"
                old.last_error_message = "A newer checkout was prepared; this confirmation is no longer valid."
                old.updated_at = now
                _log_event(db, old, "AWAITING_USER_CONFIRMATION", "CANCELLED", "CHECKOUT_INVALIDATED", "REPLACED_BY_NEW_REQUEST")

            row = PayPalCheckoutModel(
                checkout_id=f"chk_{uuid.uuid4().hex[:24]}",
                user_id=user_id,
                status="AWAITING_USER_CONFIRMATION",
                sku=product["sku"],
                item_name=product["name"][:127],
                item_description=(product.get("description") or "")[:255],
                quantity=qty,
                unit_amount=_fmt(unit),
                total_amount=_fmt(total),
                currency=currency,
                merchant_name=settings.PAYPAL_BRAND_NAME[:127],
                budget_limit=_fmt(budget_dec) if budget_dec is not None else None,
                budget_currency=budget_cur,
                user_request=(user_request or "")[:1000] or None,
                details_hash="pending",
                create_request_id=f"sika-create-{uuid.uuid4()}",
                capture_request_id=f"sika-capture-{uuid.uuid4()}",
                expires_at=now + timedelta(seconds=settings.PAYPAL_CONFIRMATION_TTL_SECONDS),
                created_at=now,
                updated_at=now,
            )
            row.details_hash = _compute_details_hash(row)
            db.add(row)
            _log_event(db, row, None, "AWAITING_USER_CONFIRMATION", "CHECKOUT_PREPARED", "PREPARED_BY_AGENT",
                       {"sku": row.sku, "quantity": qty, "total": row.total_amount, "currency": currency})
            db.commit()
            logger.info(f"[SIKA PAY] Checkout {row.checkout_id} prepared for user {user_id}: {row.total_amount} {currency}")
            return self.to_public_dict(row)

    # ==================================================================
    # Étape 2 — Confirmation utilisateur puis création de la commande PayPal
    # ==================================================================

    def confirm_and_create_order(self, user_id: int, checkout_id: str, details_hash: str) -> Dict[str, Any]:
        """Confirmation explicite de l'utilisateur dans l'app (empreinte des détails affichés)."""
        return self._confirm(user_id, checkout_id, by="USER", details_hash=details_hash)

    def confirm_by_agent(self, user_id: int, checkout_id: str) -> Dict[str, Any]:
        """Confirmation par l'agent, uniquement sous une autorisation active de l'utilisateur (limites vérifiées ici)."""
        return self._confirm(user_id, checkout_id, by="AGENT")

    def _confirm(self, user_id: int, checkout_id: str, by: str, details_hash: Optional[str] = None) -> Dict[str, Any]:
        with Session(engine) as db:
            row = self._load_owned(db, user_id, checkout_id)

            if row.status == "AWAITING_PAYPAL_APPROVAL":
                # Répétition de la confirmation : on renvoie la commande existante, sans en créer une seconde
                return {**self.to_public_dict(row), "message": "The PayPal order already exists. Approve it on PayPal."}

            if self._expire_if_needed(db, row):
                db.commit()
                raise CheckoutError("CHECKOUT_EXPIRED", "This checkout expired before confirmation. Ask SIKA to prepare it again.", 410)

            if row.status != "AWAITING_USER_CONFIRMATION":
                raise CheckoutError("INVALID_STATE", f"This checkout cannot be confirmed (status {row.status}).", 409,
                                    data={"checkout": self.to_public_dict(row)})

            if row.details_hash != _compute_details_hash(row):
                raise CheckoutError("DETAILS_CHANGED",
                                    "The checkout details changed. Review the latest summary and confirm again.", 409)
            mandate_meta = None
            if by == "USER":
                if not details_hash or not hmac.compare_digest(str(details_hash), row.details_hash):
                    raise CheckoutError("DETAILS_CHANGED",
                                        "The confirmed details do not match this checkout. Review the latest summary and confirm again.", 409)
            else:
                from .agent_mandate_service import agent_mandate_service, MandateError
                if row.budget_limit and Decimal(row.total_amount) > Decimal(row.budget_limit):
                    raise CheckoutError("OVER_BUDGET", "This purchase is above the budget you gave. Confirm it yourself in the app.", 403)
                try:
                    mandate = agent_mandate_service.check_purchase(db, user_id, row.total_amount, row.currency)
                except MandateError as e:
                    raise CheckoutError(e.code, e.message, e.http_status)
                mandate_meta = {"max_per_purchase": mandate.max_per_purchase, "daily_limit": mandate.daily_limit,
                                "mandate_expires_at": _utc(mandate.expires_at).isoformat()}

            if not self.api.is_configured():
                raise CheckoutError("PAYPAL_NOT_CONFIGURED",
                                    "PayPal sandbox credentials are not configured on the SIKA backend.", 503)

            locked = db.query(PayPalCheckoutModel).filter(
                PayPalCheckoutModel.checkout_id == row.checkout_id,
                PayPalCheckoutModel.status == "AWAITING_USER_CONFIRMATION",
            ).update({"status": "CREATING_ORDER", "confirmed_by": by, "updated_at": _now()}, synchronize_session=False)
            if locked != 1:
                db.rollback()
                raise CheckoutError("CONCURRENT_REQUEST", "This checkout is already being processed.", 409)
            if by == "USER":
                _log_event(db, row, "AWAITING_USER_CONFIRMATION", "CREATING_ORDER", "USER_CONFIRMED", "EXPLICIT_USER_CONFIRMATION")
            else:
                _log_event(db, row, "AWAITING_USER_CONFIRMATION", "CREATING_ORDER", "AGENT_CONFIRMED",
                           "UNDER_USER_AUTHORIZATION", mandate_meta)
            db.commit()
            db.refresh(row)

            items = [{
                "name": row.item_name,
                "description": (row.item_description or "")[:127],
                "sku": row.sku,
                "quantity": str(row.quantity),
                "category": "DIGITAL_GOODS",
                "unit_amount": {"currency_code": row.currency, "value": row.unit_amount},
            }]

            try:
                order = self.api.create_order(
                    reference_id=row.checkout_id,
                    custom_id=row.checkout_id,
                    currency=row.currency,
                    total=row.total_amount,
                    items=items,
                    description=f"SIKA Pay sandbox — {row.item_name}",
                    request_id=row.create_request_id,
                )
            except PayPalNetworkError:
                # Création de commande : aucun argent ne bouge. Une nouvelle tentative réutilise le même
                # PayPal-Request-Id, donc PayPal renverra la même commande au lieu d'en créer une seconde.
                self._transition(db, row, "AWAITING_USER_CONFIRMATION", "ORDER_CREATE_NETWORK_ERROR",
                                 error=("NETWORK_ERROR", "PayPal could not be reached. No payment was made; you can retry safely."))
                raise CheckoutError("PAYPAL_UNREACHABLE", "PayPal could not be reached. No payment was made; you can retry safely.", 503)
            except PayPalConfigurationError as e:
                self._transition(db, row, "AWAITING_USER_CONFIRMATION", "PAYPAL_NOT_CONFIGURED", error=("PAYPAL_NOT_CONFIGURED", str(e)))
                raise CheckoutError("PAYPAL_NOT_CONFIGURED", str(e), 503)
            except PayPalAPIError as e:
                message = paypal_error_message(e.issue, f"PayPal rejected the order ({e.issue or e.name}).") + " No payment was made."
                self._transition(db, row, "FAILED", "ORDER_CREATE_REJECTED", error=(e.issue or e.name, message), debug_id=e.debug_id)
                raise CheckoutError(e.issue if e.issue in PAYMENT_REFUSED else "PAYPAL_REJECTED", message, 502,
                                    data={"checkout": self.to_public_dict(row)})

            order_id = str(order.get("id") or "")
            order_status = str(order.get("status") or "")
            approve_url = self.api.extract_approve_url(order)
            echoed = ((order.get("purchase_units") or [{}])[0] or {}).get("amount") or {}

            problem = None
            if not order_id or order_status not in ("CREATED", "PAYER_ACTION_REQUIRED"):
                problem = ("UNEXPECTED_ORDER_STATUS", f"PayPal returned order status '{order_status}'.")
            elif not _is_paypal_url(approve_url):
                problem = ("MISSING_APPROVAL_LINK", "PayPal did not return a valid approval link.")
            elif echoed and (echoed.get("value") != row.total_amount or echoed.get("currency_code") != row.currency):
                problem = ("AMOUNT_MISMATCH", "The amount registered by PayPal differs from the confirmed amount.")

            row.paypal_order_id = order_id or None
            row.paypal_order_status = order_status or None
            if problem:
                self._transition(db, row, "FAILED", "ORDER_CREATE_INVALID_RESPONSE", error=problem)
                raise CheckoutError(problem[0], problem[1], 502, data={"checkout": self.to_public_dict(row)})

            row.approve_url = approve_url
            self._transition(db, row, "AWAITING_PAYPAL_APPROVAL", "PAYPAL_ORDER_CREATED",
                             metadata={"paypal_order_id": order_id, "paypal_status": order_status})
            return {**self.to_public_dict(row), "message": "PayPal sandbox order created. Approve it on PayPal to continue."}

    # ==================================================================
    # Étape 3 — Synchronisation (lecture seule) avec PayPal
    # ==================================================================

    def sync_with_paypal(self, user_id: int, checkout_id: str) -> Dict[str, Any]:
        with Session(engine) as db:
            row = self._load_owned(db, user_id, checkout_id)
            if self._expire_if_needed(db, row):
                db.commit()
            sync_error = None
            if row.paypal_order_id and row.status in ("AWAITING_PAYPAL_APPROVAL", "APPROVED", "UNKNOWN_RESULT", "PENDING"):
                try:
                    order = self.api.get_order(row.paypal_order_id)
                    self._apply_order_state(db, row, order, source="SYNC")
                    if row.status == "APPROVED":
                        self._auto_capture(db, row, source="SYNC")
                except PayPalNetworkError:
                    sync_error = "PayPal could not be reached to verify the status. The last verified status is shown."
                except PayPalAPIError as e:
                    if e.status_code == 404:
                        self._transition(db, row, "EXPIRED", "PAYPAL_ORDER_NOT_FOUND",
                                         error=("ORDER_NOT_FOUND", "PayPal no longer knows this order (expired). No payment was made."))
                    else:
                        sync_error = f"PayPal returned an error while verifying the status ({e.issue or e.name})."
                except PayPalConfigurationError as e:
                    sync_error = str(e)
            data = self.to_public_dict(row, events=self._events(db, row.checkout_id))
            if sync_error:
                data["sync_error"] = sync_error
            return data

    def _apply_order_state(self, db: Session, row: PayPalCheckoutModel, order: Dict[str, Any], source: str):
        """Applique un état PayPal vérifié côté serveur (jamais une affirmation du client)."""
        status = str(order.get("status") or "")
        row.paypal_order_status = status or row.paypal_order_status

        if status == "APPROVED" and row.status in ("AWAITING_PAYPAL_APPROVAL", "UNKNOWN_RESULT"):
            self._transition(db, row, "APPROVED", f"PAYPAL_APPROVED_{source}")
        elif status == "COMPLETED":
            capture = self.api.extract_capture(order)
            if capture:
                self._apply_capture(db, row, capture, source)
            else:
                db.commit()
        elif status == "VOIDED" and row.status not in TERMINAL_STATUSES:
            self._transition(db, row, "CANCELLED", f"PAYPAL_VOIDED_{source}",
                             error=("ORDER_VOIDED", "PayPal voided this order. No payment was made."))
        else:
            db.commit()

    def _apply_capture(self, db: Session, row: PayPalCheckoutModel, capture: Dict[str, Any], source: str):
        cap_status = str(capture.get("status") or "")
        amount = capture.get("amount") or {}
        row.capture_id = capture.get("id")
        row.capture_status = cap_status
        row.captured_amount = amount.get("value")
        row.captured_currency = amount.get("currency_code")

        if row.status == "COMPLETED" and cap_status in ("REFUNDED", "PARTIALLY_REFUNDED"):
            # Le paiement a bien eu lieu puis a été remboursé : on le dit, sans effacer la capture
            self._transition(db, row, "COMPLETED", f"PAYPAL_CAPTURE_{cap_status}_{source}",
                             metadata={"capture_id": row.capture_id, "capture_status": cap_status})
            return
        if row.status == "COMPLETED" and cap_status == "COMPLETED":
            db.commit()
            return
        if cap_status == "COMPLETED":
            if row.captured_amount != row.total_amount or row.captured_currency != row.currency:
                self._transition(db, row, "UNKNOWN_RESULT", f"CAPTURE_AMOUNT_MISMATCH_{source}",
                                 error=("AMOUNT_MISMATCH", "The captured amount differs from the confirmed amount. Manual review required."))
            else:
                self._transition(db, row, "COMPLETED", f"PAYPAL_CAPTURE_COMPLETED_{source}",
                                 metadata={"capture_id": row.capture_id, "amount": row.captured_amount, "currency": row.captured_currency})
        elif cap_status == "PENDING":
            reason = ((capture.get("status_details") or {}).get("reason")) or "PENDING"
            self._transition(db, row, "PENDING", f"PAYPAL_CAPTURE_PENDING_{source}",
                             error=("CAPTURE_PENDING", f"PayPal reports the capture as pending ({reason})."))
        elif cap_status in ("DECLINED", "FAILED"):
            self._transition(db, row, "DECLINED" if cap_status == "DECLINED" else "FAILED", f"PAYPAL_CAPTURE_{cap_status}_{source}",
                             error=(f"CAPTURE_{cap_status}", f"PayPal reports the capture as {cap_status.lower()}. No funds were captured."))
        else:
            self._transition(db, row, "UNKNOWN_RESULT", f"PAYPAL_CAPTURE_UNRECOGNIZED_{source}",
                             error=("UNRECOGNIZED_CAPTURE_STATUS", f"Unrecognized capture status '{cap_status}'."))

    # ==================================================================
    # Étape 4 — Capture (après approbation vérifiée auprès de PayPal)
    # ==================================================================

    def capture(self, user_id: int, checkout_id: str) -> Dict[str, Any]:
        """Capture demandée depuis l'app (repli si la capture automatique n'a pas encore eu lieu)."""
        with Session(engine) as db:
            row = self._load_owned(db, user_id, checkout_id)
            return self._capture_row(db, row, source="USER")

    def _auto_capture(self, db: Session, row: PayPalCheckoutModel, source: str):
        """L'acheteur a confirmé dans SIKA (ou via son autorisation) puis approuvé sur PayPal :
        comme dans le parcours PayPal standard, la capture suit l'approbation sans nouvelle question."""
        try:
            self._capture_row(db, row, source=source)
        except CheckoutError as e:
            logger.info(f"[SIKA PAY] Auto-capture {row.checkout_id} not completed ({source}): {e.code}")

    def _capture_row(self, db: Session, row: PayPalCheckoutModel, source: str) -> Dict[str, Any]:
        if row.status == "COMPLETED":
            return {**self.to_public_dict(row), "already_completed": True,
                    "message": "This payment was already captured. No second capture was attempted."}
        if row.status == "CAPTURING":
            raise CheckoutError("CAPTURE_IN_PROGRESS", "A capture is already in progress for this checkout.", 409)
        if row.status not in ("APPROVED", "AWAITING_PAYPAL_APPROVAL", "UNKNOWN_RESULT") or not row.paypal_order_id:
            raise CheckoutError("INVALID_STATE", f"This checkout cannot be captured (status {row.status}).", 409,
                                data={"checkout": self.to_public_dict(row)})

        # Vérification serveur : seule la réponse de PayPal fait foi, jamais le client mobile
        try:
            order = self.api.get_order(row.paypal_order_id)
        except PayPalNetworkError:
            raise CheckoutError("PAYPAL_UNREACHABLE", "PayPal could not be reached to verify the approval. Nothing was captured.", 503)
        except PayPalAPIError as e:
            if e.status_code == 404:
                self._transition(db, row, "EXPIRED", "PAYPAL_ORDER_NOT_FOUND",
                                 error=("INVALID_RESOURCE_ID", "PayPal no longer knows this order (expired). No payment was made."))
                raise CheckoutError("ORDER_EXPIRED", "PayPal no longer knows this order (expired). No payment was made.", 410,
                                    data={"checkout": self.to_public_dict(row)})
            raise CheckoutError("PAYPAL_REJECTED", f"PayPal could not verify the order ({e.issue or e.name}).", 502)

        order_status = str(order.get("status") or "")
        if order_status == "COMPLETED":
            self._apply_order_state(db, row, order, source=f"PRE_CAPTURE_CHECK_{source}")
            return {**self.to_public_dict(row), "already_completed": row.status == "COMPLETED",
                    "message": "PayPal reports this order as already completed. No second capture was attempted."}
        if order_status != "APPROVED":
            row.paypal_order_status = order_status or row.paypal_order_status
            db.commit()
            raise CheckoutError("ORDER_NOT_APPROVED",
                                "PayPal has not approved this order yet. Approve it on PayPal first.", 409,
                                data={"checkout": self.to_public_dict(row)})

        unit = ((order.get("purchase_units") or [{}])[0] or {}).get("amount") or {}
        if unit and (unit.get("value") != row.total_amount or unit.get("currency_code") != row.currency):
            self._transition(db, row, "FAILED", "PRE_CAPTURE_AMOUNT_MISMATCH",
                             error=("AMOUNT_MISMATCH", "PayPal order amount differs from the confirmed amount. Capture refused."))
            raise CheckoutError("AMOUNT_MISMATCH", "PayPal order amount differs from the confirmed amount. Capture refused.", 409)

        previous = row.status
        locked = db.query(PayPalCheckoutModel).filter(
            PayPalCheckoutModel.checkout_id == row.checkout_id,
            PayPalCheckoutModel.status == previous,
        ).update({"status": "CAPTURING", "paypal_order_status": "APPROVED", "updated_at": _now()}, synchronize_session=False)
        if locked != 1:
            db.rollback()
            raise CheckoutError("CONCURRENT_REQUEST", "This checkout is already being processed.", 409)
        _log_event(db, row, previous, "CAPTURING", "CAPTURE_STARTED", f"PAYPAL_APPROVAL_VERIFIED_{source}")
        db.commit()
        db.refresh(row)

        try:
            captured_order = self.api.capture_order(row.paypal_order_id, request_id=row.capture_request_id)
        except PayPalNetworkError:
            self._transition(db, row, "UNKNOWN_RESULT", "CAPTURE_NETWORK_ERROR",
                             error=("NETWORK_ERROR", "The capture result is unknown. SIKA will verify with PayPal; "
                                                     "a retry reuses the same PayPal-Request-Id and cannot double-charge."))
            return {**self.to_public_dict(row), "message": "The capture result is unknown. Verify the status before any retry."}
        except PayPalAPIError as e:
            if e.issue == "ORDER_ALREADY_CAPTURED":
                try:
                    self._apply_order_state(db, row, self.api.get_order(row.paypal_order_id), source="ALREADY_CAPTURED")
                except (PayPalNetworkError, PayPalAPIError):
                    self._transition(db, row, "UNKNOWN_RESULT", "ALREADY_CAPTURED_UNVERIFIED",
                                     error=("ORDER_ALREADY_CAPTURED", "PayPal says this order was already captured."))
                return {**self.to_public_dict(row), "message": "PayPal reports this order as already captured."}
            if e.issue in PAYER_MUST_REAPPROVE:
                # Le lien d'approbation reste valable : le payeur choisit un autre moyen de paiement sur PayPal
                message = PAYER_MUST_REAPPROVE[e.issue]
                self._transition(db, row, "AWAITING_PAYPAL_APPROVAL", f"CAPTURE_REJECTED_{e.issue}",
                                 error=(e.issue, message), debug_id=e.debug_id)
                raise CheckoutError(e.issue, message, 409, data={"checkout": self.to_public_dict(row)})
            if e.issue in PAYMENT_REFUSED:
                message = PAYMENT_REFUSED[e.issue] + " No funds were captured."
                self._transition(db, row, "DECLINED", f"CAPTURE_REFUSED_{e.issue}", error=(e.issue, message), debug_id=e.debug_id)
                raise CheckoutError(e.issue, message, 422, data={"checkout": self.to_public_dict(row)})
            if e.status_code == 404:
                self._transition(db, row, "EXPIRED", "PAYPAL_ORDER_NOT_FOUND",
                                 error=("INVALID_RESOURCE_ID", "PayPal no longer knows this order (expired). No payment was made."))
                raise CheckoutError("ORDER_EXPIRED", "PayPal no longer knows this order (expired). No payment was made.", 410,
                                    data={"checkout": self.to_public_dict(row)})
            self._transition(db, row, "FAILED", "CAPTURE_REJECTED",
                             error=(e.issue or e.name, e.message or "PayPal rejected the capture."), debug_id=e.debug_id)
            raise CheckoutError("PAYPAL_REJECTED", f"PayPal rejected the capture ({e.issue or e.name}). No funds were captured.", 502,
                                data={"checkout": self.to_public_dict(row)})

        row.paypal_order_status = str(captured_order.get("status") or row.paypal_order_status)
        capture = self.api.extract_capture(captured_order)
        if not capture:
            self._transition(db, row, "UNKNOWN_RESULT", "CAPTURE_RESPONSE_WITHOUT_CAPTURE",
                             error=("MISSING_CAPTURE", "PayPal did not return capture details. Verify before any retry."))
        else:
            self._apply_capture(db, row, capture, source=f"CAPTURE_{source}")
            row.result_json = json.dumps({"order_status": row.paypal_order_status, "capture_id": row.capture_id,
                                          "capture_status": row.capture_status})
            db.commit()
        return {**self.to_public_dict(row), "message": STATUS_LABELS.get(row.status, row.status)}

    # ==================================================================
    # Annulation et redirections PayPal
    # ==================================================================

    def cancel(self, user_id: int, checkout_id: str, reason: str = "USER_CANCELLED") -> Dict[str, Any]:
        with Session(engine) as db:
            row = self._load_owned(db, user_id, checkout_id)
            if row.status == "CANCELLED":
                return {**self.to_public_dict(row), "message": "This checkout was already cancelled."}
            cancellable = ("AWAITING_USER_CONFIRMATION", "AWAITING_PAYPAL_APPROVAL", "APPROVED")
            previous = row.status
            affected = db.query(PayPalCheckoutModel).filter(
                PayPalCheckoutModel.checkout_id == row.checkout_id,
                PayPalCheckoutModel.status.in_(cancellable),
            ).update({"status": "CANCELLED", "last_error_code": "USER_CANCELLED",
                      "last_error_message": "Cancelled by the user. No payment was captured.", "updated_at": _now()},
                     synchronize_session=False)
            if affected != 1:
                db.rollback()
                raise CheckoutError("INVALID_STATE", f"This checkout can no longer be cancelled (status {row.status}).", 409,
                                    data={"checkout": self.to_public_dict(row)})
            _log_event(db, row, previous, "CANCELLED", "CHECKOUT_CANCELLED", (reason or "USER_CANCELLED")[:100])
            db.commit()
            db.refresh(row)
            # Une commande Orders v2 non capturée n'est jamais débitée ; PayPal la fait expirer.
            return {**self.to_public_dict(row), "message": "Checkout cancelled. No payment was captured."}

    def handle_payer_return(self, order_id: str) -> Optional[str]:
        """Retour depuis PayPal (non authentifié) : on ne fait confiance qu'à un GET order côté serveur,
        puis on capture si PayPal confirme l'approbation."""
        with Session(engine) as db:
            row = db.query(PayPalCheckoutModel).filter(PayPalCheckoutModel.paypal_order_id == str(order_id)).first()
            if not row:
                return None
            if row.status == "AWAITING_PAYPAL_APPROVAL":
                try:
                    self._apply_order_state(db, row, self.api.get_order(row.paypal_order_id), source="RETURN")
                except (PayPalNetworkError, PayPalAPIError, PayPalConfigurationError, ValueError) as e:
                    logger.warning(f"[SIKA PAY] Return sync failed for {row.checkout_id}: {type(e).__name__}")
            if row.status == "APPROVED":
                self._auto_capture(db, row, source="RETURN")
            return row.status

    def handle_payer_cancel(self, order_id: str) -> Optional[str]:
        with Session(engine) as db:
            row = db.query(PayPalCheckoutModel).filter(PayPalCheckoutModel.paypal_order_id == str(order_id)).first()
            if not row:
                return None
            if row.status == "AWAITING_PAYPAL_APPROVAL":
                self._transition(db, row, "CANCELLED", "PAYER_CANCELLED_AT_PAYPAL",
                                 error=("PAYER_CANCELLED", "You cancelled on PayPal. No payment was made."))
            return row.status

    # ==================================================================
    # Webhooks PayPal (signature déjà vérifiée par la route)
    # ==================================================================

    WEBHOOK_EVENTS = (
        "CHECKOUT.ORDER.APPROVED",
        "PAYMENT.CAPTURE.COMPLETED",
        "PAYMENT.CAPTURE.PENDING",
        "PAYMENT.CAPTURE.DENIED",
        "PAYMENT.CAPTURE.DECLINED",
        "PAYMENT.CAPTURE.REFUNDED",
        "PAYMENT.CAPTURE.REVERSED",
        "BILLING.SUBSCRIPTION.ACTIVATED",
        "BILLING.SUBSCRIPTION.CANCELLED",
        "BILLING.SUBSCRIPTION.SUSPENDED",
        "BILLING.SUBSCRIPTION.EXPIRED",
        "BILLING.SUBSCRIPTION.PAYMENT.FAILED",
        "PAYMENT.SALE.COMPLETED",
    )

    def handle_webhook_event(self, event: Dict[str, Any]) -> str:
        """Applique un événement PayPal. Le contenu de l'événement sert seulement à retrouver la commande :
        l'état appliqué vient toujours d'un GET /v2/checkout/orders côté serveur."""
        event_type = str(event.get("event_type") or "")
        resource = event.get("resource") or {}
        if event_type.startswith("BILLING.SUBSCRIPTION.") or event_type == "PAYMENT.SALE.COMPLETED":
            from .paypal_subscription_service import paypal_subscription_service
            sub_id = resource.get("billing_agreement_id") if event_type == "PAYMENT.SALE.COMPLETED" else resource.get("id")
            if not sub_id:
                return "NO_SUBSCRIPTION_ID"
            status = paypal_subscription_service.refresh_by_paypal_id(str(sub_id))
            return f"SUBSCRIPTION_{status}" if status else "UNKNOWN_SUBSCRIPTION"
        if event_type == "CHECKOUT.ORDER.APPROVED":
            order_id = resource.get("id")
        else:
            order_id = (((resource.get("supplementary_data") or {}).get("related_ids") or {}).get("order_id"))
        if event_type not in self.WEBHOOK_EVENTS:
            return "IGNORED_EVENT_TYPE"
        if not order_id:
            return "NO_ORDER_ID"
        with Session(engine) as db:
            row = db.query(PayPalCheckoutModel).filter(PayPalCheckoutModel.paypal_order_id == str(order_id)).first()
            if not row:
                return "UNKNOWN_ORDER"
            _log_event(db, row, row.status, row.status, "PAYPAL_WEBHOOK_RECEIVED", event_type[:100])
            db.commit()
            if row.status == "CAPTURING":
                return "CAPTURE_IN_PROGRESS"
            try:
                self._apply_order_state(db, row, self.api.get_order(row.paypal_order_id), source="WEBHOOK")
            except (PayPalNetworkError, PayPalAPIError, PayPalConfigurationError) as e:
                logger.warning(f"[SIKA PAY] Webhook sync failed for {row.checkout_id}: {type(e).__name__}")
                return "SYNC_FAILED"
            if row.status == "APPROVED":
                self._auto_capture(db, row, source="WEBHOOK")
            return f"STATUS_{row.status}"

    # ==================================================================
    # Utilitaires internes
    # ==================================================================

    def _expire_if_needed(self, db: Session, row: PayPalCheckoutModel) -> bool:
        if row.status == "AWAITING_USER_CONFIRMATION" and row.expires_at and _now() > _utc(row.expires_at):
            row.status = "EXPIRED"
            row.last_error_code = "CONFIRMATION_EXPIRED"
            row.last_error_message = "The confirmation window expired. No PayPal order was created."
            row.updated_at = _now()
            _log_event(db, row, "AWAITING_USER_CONFIRMATION", "EXPIRED", "CHECKOUT_EXPIRED", "CONFIRMATION_TTL")
            return True
        return False

    def _transition(self, db: Session, row: PayPalCheckoutModel, new_status: str, event_type: str,
                    error: Optional[tuple] = None, debug_id: Optional[str] = None, metadata: Optional[dict] = None):
        previous = row.status
        row.status = new_status
        row.updated_at = _now()
        if error:
            row.last_error_code = str(error[0])[:80]
            row.last_error_message = str(error[1])[:255]
        elif new_status in ("APPROVED", "AWAITING_PAYPAL_APPROVAL", "COMPLETED"):
            row.last_error_code = None
            row.last_error_message = None
        if debug_id:
            row.paypal_debug_id = debug_id[:64]
        _log_event(db, row, previous, new_status, event_type, error[0] if error else None, metadata)
        db.commit()
        logger.info(f"[SIKA PAY] {row.checkout_id}: {previous} -> {new_status} ({event_type})")


paypal_checkout_service = PayPalCheckoutService()
