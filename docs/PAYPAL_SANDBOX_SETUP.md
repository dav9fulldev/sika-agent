# PayPal Sandbox Setup — SIKA Pay

SIKA Pay only uses the **PayPal sandbox**. No real account is charged and no real money moves.

## 1. Create the sandbox REST app (backend credentials)

1. Sign in at <https://developer.paypal.com> with any PayPal account. A free account is enough.
2. Go to **Apps & Credentials** and make sure the **Sandbox** toggle is selected.
3. Click **Create App**, name it `SIKA Pay`, choose type **Merchant**, and pick the default sandbox *business* account.
4. Copy the **Client ID** and the **Secret**.
5. Put them in `backend/.env`. This file is git-ignored, so never put the values in the Flutter app or in a commit:

```env
PAYPAL_ENV=sandbox
PAYPAL_API_BASE=https://api-m.sandbox.paypal.com
PAYPAL_CLIENT_ID=<sandbox client id>
PAYPAL_CLIENT_SECRET=<sandbox secret>
PUBLIC_BASE_URL=http://<backend address reachable from the phone>:8001
```

`PUBLIC_BASE_URL` builds the PayPal `return_url` and `cancel_url` (`/api/v1/paypal/return` and `/cancel`). The phone's browser must be able to reach it: use the computer's LAN IP on the same Wi-Fi, or a public HTTPS URL if you deploy the backend.

## 2. Get a sandbox buyer account (used on the phone to approve)

1. Go to **Testing Tools → Sandbox Accounts**.
2. A *Personal* (buyer) account exists by default. Open **⋯ → View/Edit account** to read its email and password, or create a new Personal account.
3. Sandbox buyers come with a fake balance. Use this account on the PayPal approval page during the demo.

## 3. Verify the configuration

```bash
cd backend && source venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8001
curl http://localhost:8001/api/v1/paypal/status
# {"provider":"PAYPAL","environment":"sandbox","configured":true, ...}   (no secret is ever returned)
```

Then run the real end-to-end check (no app needed):

```bash
python scripts/paypal_sandbox_e2e.py
# 1. OAuth2 OK  2. checkout prepared  3. PayPal order created + approval link
# → open the link, log in with the sandbox BUYER, approve
# 4-5. status verified APPROVED  6. capture COMPLETED + amount verified, second capture refused
```

## 4. Safety guarantees

- The backend refuses to start if `PAYPAL_ENV` is not `sandbox` or if `PAYPAL_API_BASE` is not a sandbox host.
- Credentials and access tokens are never logged or returned by any endpoint.
- Every order creation and capture sends a stable `PayPal-Request-Id`, so retries are idempotent.
- A capture is only attempted after `GET /v2/checkout/orders/{id}` returns `APPROVED` with the confirmed amount.

## 5. For hackathon judges

The rules allow testers to use their own sandbox credentials. Follow steps 1 to 3 with your own PayPal developer account; it takes about five minutes. If the owner chooses to share a dedicated, revocable sandbox app for judging, put those credentials in the Devpost *testing instructions* field, never in the repository.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `PAYPAL_NOT_CONFIGURED` (503) | Client ID or secret missing in `backend/.env`; restart the backend |
| `AUTHENTICATION_FAILURE` | Live credentials used instead of sandbox, or the secret was regenerated |
| PayPal page never returns to SIKA | `PUBLIC_BASE_URL` is not reachable from the phone. Come back to the app manually: it re-checks the status on resume, and "I've approved — check" also works |
| `ORDER_NOT_APPROVED` on "Pay now" | The order was not approved with the sandbox buyer yet |
| `INSTRUMENT_DECLINED` | PayPal asks the payer to choose another funding source: tap **Open PayPal** again |
