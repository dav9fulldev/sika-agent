# Hackathon progress — what existed vs. what was built

The rules allow existing projects that are **significantly updated during the submission period** (Oct 1 – Nov 12, 2026). This page documents both honestly.

## Before the submission period (SIKA v1.0.x, August–October 2026)

Built for the Google "All Things Agentic" hackathon (August 2026):

- Flutter app: authentication, onboarding, chat and voice UI (STT/TTS), biometrics (`local_auth`), Android wake-word and overlay services.
- FastAPI backend: JWT auth with revocation, rate limiting, Gemini via Vertex AI (`google-genai`), a tool registry with three risk levels, and an action audit trail.
- Payment layer: a Mobile Money integration with the owner's own platform. Transfers were prepared by the agent and executed after in-app confirmation.

## Built for the PayPal AI Hackathon (October 2026)

### New PayPal integration (Orders v2, sandbox)
- `paypal_api_service.py`: OAuth2 client_credentials with a token cache, create, get and capture order, `PayPal-Request-Id` idempotency, parsing of official errors (`name`, `issue`, `debug_id`), network errors mapped to "unknown result", and a sandbox-only configuration guard.
- `paypal_checkout_service.py`: a 12-state checkout state machine; server-side pricing; budget, currency and maximum-amount checks; a SHA-256 binding between what the user saw and what they confirmed; verification of `APPROVED` with PayPal before capture; checks of the captured amount and currency; safe retries; payer return and cancel handling; an append-only audit trail.
- `paypal_router.py`: authenticated `/api/v1/paypal/*` endpoints and server-verified return and cancel pages.
- New `paypal_checkouts` table plus an Alembic migration.

### New agentic commerce behaviour
- New strict-schema tools: `search_demo_catalog`, `prepare_paypal_checkout`, `get_paypal_checkout_status` and `list_recent_paypal_checkouts`. The model never sees `user_id` and cannot pass an amount.
- No tool can create or capture a payment; only the authenticated user can.
- Rewritten system prompt (SIKA Pay policy: search first, ask when ambiguous, never merge "created", "approved" and "captured").
- Gemini explains a prepared checkout after the tool result, with a deterministic fallback text.
- Deterministic fallback engine for commerce requests, honestly labelled `SIKA_LOCAL_FALLBACK`.
- Gemini Developer API key support (`GEMINI_API_KEY`) so that judges can run the AI without a GCP project.

### Security fixes found during the audit
- ReAct loop was unbounded (`step` was never incremented): now limited to 5 steps.
- The SDK's automatic function calling bypassed the tool registry: disabled.
- A model-supplied `user_id` could be accepted: now always injected by the server.
- Hard-coded partner secret in the source: removed (it must still be rotated, because it remains in the Git history).
- Tests could `drop_all()` on the database configured in `.env`: tests now always use a throwaway SQLite file.

### New mobile experience (Flutter)
- SIKA Pay home: PayPal card, quick actions, sandbox connection status (no invented balance) and recent payments.
- In-chat checkout card that tracks the live status.
- Full payment flow screen: details and provenance ("what SIKA verified"), biometric confirmation, PayPal approval in the browser with automatic re-check when the app resumes, a final "Pay now" capture, and a receipt with the order and capture IDs plus the audit trail.
- Transactions tab (SIKA Pay history), new navigation labels, EN/FR strings.

### Removed
At the owner's request, the previous Mobile Money provider integration was removed entirely: its API client, wallet routes, transfer tools, the legacy offline engine, the wallet UI, related tests and assets. The unverified Wave, Orange and MTN stubs that depended on it were removed too. PayPal is now the only payment provider.

## Evidence

| Check | Before (commit `e0fcaea`) | After |
|---|---|---|
| Backend tests | 2 failing; 1 file hung for more than 150 s | **130 passed** (incl. version consistency), repeated runs, about 15 s, no network |
| PayPal-specific tests | none | 65 (checkout state machine: 38, HTTP client: 9, agent: 18) |
| `flutter analyze` | – | 0 issues |
| `flutter test` | – | 12 passed |
| Live Gemini check (Vertex AI) | – | prepares within budget, refuses over budget with alternatives, asks when ambiguous |
| Real PayPal sandbox run | – | ⏳ pending sandbox credentials (`backend/scripts/paypal_sandbox_e2e.py`) |
