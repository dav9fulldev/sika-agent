"""
Double de test du client PayPal Orders v2 (utilisé UNIQUEMENT par pytest).

Il reproduit la forme des réponses documentées de l'API sandbox
(https://developer.paypal.com/docs/api/orders/v2/) sans aucun appel réseau, afin de
tester la machine à états de SIKA Pay. Il ne sert jamais à l'exécution de l'application.
"""

import itertools
from typing import Dict, Any, List

from app.services.wallet_integrations.paypal_api_service import PayPalAPIError, PayPalNetworkError, PayPalAPIService

_ids = itertools.count(1)


class FakePayPalAPI:
    def __init__(self):
        self.configured = True
        self.orders: Dict[str, Dict[str, Any]] = {}
        self.calls: List[tuple] = []
        self.create_failure = None   # exception levée au prochain create_order
        self.capture_failure = None  # exception levée au prochain capture_order
        self.capture_status = "COMPLETED"
        self.captured_value_override = None
        self.order_amount_override = None
        self.create_status = "PAYER_ACTION_REQUIRED"
        self._by_request_id: Dict[str, str] = {}

    # API publique identique à PayPalAPIService
    def is_configured(self):
        return self.configured

    extract_approve_url = staticmethod(PayPalAPIService.extract_approve_url)
    extract_capture = staticmethod(PayPalAPIService.extract_capture)

    def create_order(self, *, reference_id, currency, total, items, description, request_id, custom_id):
        self.calls.append(("create", request_id))
        if self.create_failure:
            exc, self.create_failure = self.create_failure, None
            raise exc
        if request_id in self._by_request_id:  # idempotence PayPal-Request-Id
            return self._repr(self._by_request_id[request_id])
        order_id = f"5O190127TN{next(_ids):07d}"
        self.orders[order_id] = {
            "id": order_id, "status": self.create_status,
            "amount": {"currency_code": currency, "value": self.order_amount_override or total},
            "reference_id": reference_id, "items": items, "captures": [],
        }
        self._by_request_id[request_id] = order_id
        return self._repr(order_id)

    def get_order(self, order_id):
        self.calls.append(("get", order_id))
        if order_id not in self.orders:
            raise PayPalAPIError(404, name="RESOURCE_NOT_FOUND", issue="INVALID_RESOURCE_ID")
        return self._repr(order_id)

    def capture_order(self, order_id, request_id):
        self.calls.append(("capture", request_id))
        if self.capture_failure:
            exc, self.capture_failure = self.capture_failure, None
            raise exc
        order = self.orders[order_id]
        if order["captures"]:
            raise PayPalAPIError(422, name="UNPROCESSABLE_ENTITY", issue="ORDER_ALREADY_CAPTURED")
        if order["status"] != "APPROVED":
            raise PayPalAPIError(422, name="UNPROCESSABLE_ENTITY", issue="ORDER_NOT_APPROVED")
        value = self.captured_value_override or order["amount"]["value"]
        order["captures"].append({
            "id": f"3C679366HH{next(_ids):07d}", "status": self.capture_status,
            "amount": {"currency_code": order["amount"]["currency_code"], "value": value},
        })
        order["status"] = "COMPLETED"
        return self._repr(order_id)

    # Pilotage du test : simule l'approbation du payeur sur le site PayPal
    def approve(self, order_id):
        self.orders[order_id]["status"] = "APPROVED"

    def capture_count(self):
        return sum(1 for c in self.calls if c[0] == "capture")

    def _repr(self, order_id):
        o = self.orders[order_id]
        unit = {"reference_id": o["reference_id"], "amount": dict(o["amount"])}
        if o["captures"]:
            unit["payments"] = {"captures": [dict(c) for c in o["captures"]]}
        links = [{"href": f"https://api-m.sandbox.paypal.com/v2/checkout/orders/{order_id}", "rel": "self", "method": "GET"}]
        if o["status"] in ("CREATED", "PAYER_ACTION_REQUIRED"):
            links.append({"href": f"https://www.sandbox.paypal.com/checkoutnow?token={order_id}", "rel": "payer-action", "method": "GET"})
        return {"id": order_id, "status": o["status"], "purchase_units": [unit], "links": links}


NETWORK_ERROR = PayPalNetworkError("ReadTimeout")
