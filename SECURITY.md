# Security

## Scope
SIKA Pay only talks to the **PayPal sandbox**: the backend refuses to start with a non-sandbox PayPal host. No real money can move.

- PayPal and Gemini credentials live in `backend/.env` (git-ignored) locally and in Google Secret Manager in production. They are never shipped in the mobile app, logged or returned by the API.
- PayPal webhooks are processed only after `POST /v1/notifications/verify-webhook-signature` confirms the signature. Each event is processed once.
- The AI agent never receives an amount from the user or the model, never sees `user_id`, and has no tool that captures a payment. It can confirm a purchase only under an authorization the user granted, with limits enforced server-side.

## Past incident
A legacy partner credential, committed before v2.0.0 for the former Mobile Money integration, was removed in v2.0.0 and **revoked on 2026-10-27**. It no longer grants any access.

## Reporting a vulnerability
Please open a private security advisory on GitHub (**Security → Report a vulnerability**) or contact the repository owner directly. Do not open a public issue for security problems.
