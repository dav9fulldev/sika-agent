# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] — 2026-10-23 — SIKA Pay

SIKA becomes **SIKA Pay**: an AI payment agent built on the **PayPal REST API (Orders v2, sandbox)** for the PayPal AI Hackathon 2026.
This is a **major** release: the previous Mobile Money payment layer was removed and several API endpoints no longer exist.

### ⚠️ Breaking changes
- Removed the previous Mobile Money provider integration (API client, wallet enrollment, payouts, savings vaults) and the unverified Wave, Orange Money and MTN stubs.
- Removed endpoints `/api/v1/wallets/*`, `POST /api/v1/sika/agent/confirm`, `POST /api/v1/sika/agent/cancel`, `POST /api/v1/sika/actions/{id}/reconcile` and `POST /api/v1/sika/actions/cleanup-stale`.
- Removed agent tools `get_wallets`, `get_wallet_balance`, `get_total_balance`, `search_contact`, `get_recent_transactions`, `get_spending_summary`, `get_financial_context`, `prepare_transfer` and `confirm_transfer`.
- Removed the legacy offline rules engine (`_chat_basic`) and the unused `mcp_server` module.
- Mobile: removed the wallet feature, the agent hub, the spending insights screen and the transfer confirmation card.
- The `PAYMECHAP_*` environment variables are no longer read.

### Added
- **PayPal Orders v2 (sandbox)**: OAuth2 client credentials, order creation, server-side approval check, capture, and official error handling (`ORDER_NOT_APPROVED`, `ORDER_ALREADY_CAPTURED`, `INSTRUMENT_DECLINED`, …).
- `PayPalCheckoutService`: 12-state checkout state machine, server-side pricing, budget, currency and maximum-amount checks, a SHA-256 binding between the confirmed details and the order, stable `PayPal-Request-Id` idempotency for create and capture, verification of the captured amount, and an append-only audit trail.
- Endpoints `/api/v1/paypal/status`, `/catalog`, `/checkouts` (prepare, list), `/checkouts/{id}` (details, `?sync=true`), `/checkouts/{id}/confirm`, `/capture` and `/cancel`, plus server-verified `/return` and `/cancel` pages.
- Agent tools with strict schemas: `search_demo_catalog`, `prepare_paypal_checkout`, `get_paypal_checkout_status` and `list_recent_paypal_checkouts`. No tool can create or capture a payment, and the model can never pass an amount.
- SIKA Pay agent policy (Gemini): search before preparing, ask when ambiguous, explain over-budget refusals with alternatives, and never merge the "created", "approved" and "captured" states.
- Deterministic fallback for purchase requests, labelled `SIKA_LOCAL_FALLBACK`.
- `GEMINI_API_KEY` support (Gemini Developer API) as an alternative to Vertex AI.
- `paypal_checkouts` table and Alembic migration `7c3e9a1f2b40`.
- `backend/scripts/paypal_sandbox_e2e.py`: real end-to-end check against the PayPal sandbox.
- Mobile: SIKA Pay home, payment flow (details, biometric confirmation, PayPal approval, "Pay now", receipt with audit trail), Transactions tab, in-chat checkout card, `sikapay://paypal` deep link and `url_launcher`.
- Docs: `docs/PAYPAL_SANDBOX_SETUP.md`, `PAYPAL_HACKATHON_AUDIT.md`, `DEMO_SCRIPT.md`, `DEMO_CHECKLIST.md`, `HACKATHON_PROGRESS.md`, plus `CONTEXT.md`, `HISTORY.md` and `CLAUDE.md`.
- 65 PayPal tests (state machine, HTTP client, agent) and 5 Flutter tests.

### Changed
- README rewritten for SIKA Pay, with measured test results only.
- `docker-compose.yml` reads `backend/.env` (optional) for PayPal and Gemini settings.
- The language detector recognises purchase vocabulary in English and French.
- Bottom navigation: Home, Assistant, Transactions, Profile, with labels.
- API and app version set to `2.0.0`.

### Fixed
- The agent ReAct loop was unbounded because `step` was never incremented, which made `test_gemini_integration` hang. It is now limited to 5 steps.
- The SDK's automatic function calling executed tools outside the tool registry. It is now disabled.
- A model-supplied `user_id` could be accepted. It is now always injected server-side.
- `test_alembic_migrations_schema_integrity` depended on the order of `glob()`.

### Security
- Removed a hard-coded third-party partner secret from the source code. **It must be rotated**, because it remains in the Git history.
- Tests now always use a throwaway SQLite database and can never `drop_all()` the database configured in `.env`.
- The backend refuses to start unless the PayPal configuration targets the sandbox.

## [1.0.1] — 2026-10-23
### Security
- Dependency upgrades to address reported vulnerabilities.

## [1.0.0] — 2026-08-31
### Added
- First public release of SIKA (Google "All Things Agentic" Hackathon): Flutter voice and chat agent, FastAPI backend, Gemini via Vertex AI, risk-tiered tool registry, human-in-the-loop confirmation with biometrics, and a Mobile Money integration.

[2.0.0]: https://github.com/dav9fulldev/sika-agent/compare/v1.0.1...v2.0.0
[1.0.1]: https://github.com/dav9fulldev/sika-agent/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/dav9fulldev/sika-agent/releases/tag/v1.0.0
