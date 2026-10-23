# CLAUDE.md — SIKA Pay

Guide for AI coding agents working in this repository. Read `CONTEXT.md` (product, rules) and `HISTORY.md` (decisions) first.

## Layout
- `backend/`: FastAPI (Python 3.11+, tested on 3.14). Entry point `app/main.py`.
  - `app/services/wallet_integrations/paypal_api_service.py`: PayPal Orders v2 REST client (sandbox only)
  - `app/services/paypal_checkout_service.py`: checkout state machine, the **only** code allowed to create or capture PayPal orders
  - `app/routes/paypal_router.py`: `/api/v1/paypal/*`
  - `app/agent/tools/commerce_tools.py` + `app/agent/tools/__init__.py`: agent tools and their registration
  - `app/agent/tool_registry.py`: allow-list exposed to Gemini (`agent_tool_names()`)
  - `app/services/sika_ai.py`: Gemini agent loop (`chat()`) and deterministic fallback
  - `app/services/demo_catalog.py`: fictional demo catalog (demo data)
- `mobile/`: Flutter app. SIKA Pay UI lives in `lib/features/paypal/`; chat in `lib/features/ai_assistant/`.
- `docs/`: audit, sandbox setup, demo script and checklist, hackathon progress.

## Commands
```bash
# backend
cd backend && source venv/bin/activate        # or test_venv/bin/python locally
pytest -q                                       # 130 tests, no network
uvicorn app.main:app --host 0.0.0.0 --port 8001
python scripts/paypal_sandbox_e2e.py            # REAL sandbox run (needs PAYPAL_* in .env)

# mobile
cd mobile && flutter analyze && flutter test
flutter run --dart-define=SIKA_API_URL=http://<LAN-IP>:8001
```

## Hard rules
1. **Sandbox only.** `Settings._validate_paypal_constraints` must keep rejecting non-sandbox hosts.
2. **Never expose a tool that creates, confirms or captures a payment to the model.** New tools that touch money must be `CONFIRMATION_REQUIRED` and must not call PayPal.
3. Amounts come from the server (catalog), never from the model or the mobile client. Use `Decimal` and two-decimal strings.
4. `user_id` is always injected server-side in the agent loop; never trust model arguments for identity.
5. Keep `PayPal-Request-Id` stable per checkout for create and capture. Network errors → `UNKNOWN_RESULT`, never success.
6. Only a verified `COMPLETED` capture with a matching amount may be shown as a successful payment.
7. Secrets only in `backend/.env` (git-ignored). Never log tokens or secrets.
8. Tests must not hit the network: use `tests/paypal_fakes.FakePayPalAPI`. `tests/conftest.py` forces a throwaway SQLite DB, so do not remove that.
9. PayPal is the only payment provider. Do not reintroduce the removed Mobile Money integration.
10. Do not claim a test or sandbox run you did not execute. Update `docs/HACKATHON_PROGRESS.md` with real results.

## Conventions
- Backend comments and docstrings are mostly in French; user-facing API messages for SIKA Pay are in English. Mobile strings use `langNotifier.tr(fr, en)`.
- Errors from checkout logic: raise `CheckoutError(code, message, http_status, data)`; routes convert them to `{"detail": {...}}`.
- Every status transition goes through `PayPalCheckoutService._transition`, which writes the audit event.
- Flutter state: Riverpod `StateNotifier`. SIKA Pay state is in `paypalCheckoutsProvider`, keyed by checkout ID; the UI shows only backend data.
