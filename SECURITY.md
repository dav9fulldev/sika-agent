# Security

## Scope
SIKA Pay only talks to the **PayPal sandbox**: the backend refuses to start with a non-sandbox PayPal host. PayPal and Gemini credentials live only in `backend/.env`, which is git-ignored. They are never shipped in the mobile app, logged or returned by the API.

## Known exposure: legacy partner credential (action required by the owner)
Before v2.0.0, a hard-coded default partner credential for the former Mobile Money provider was committed to this repository:

- introduced in commit `63fba5c` (2026-08-18) in `backend/app/services/wallet_integrations/paymechap_api_service.py`;
- removed from the code in v2.0.0 (commit `d0d40d3`, 2026-10-23); the integration itself was deleted.

The value **remains readable in the Git history**. Treat it as compromised:

1. **Revoke or rotate it** in the partner platform's administration. This is the only real remediation.
2. Mark the corresponding GitGuardian incident as *revoked* once done.
3. Rewriting the public history (for example with `git filter-repo`) is **not** recommended. It would not invalidate copies that have already been cloned, and it would break existing commits, tags and pull requests.

As of the last repository audit (2026-10-24), revocation had **not** been confirmed.

## Reporting a vulnerability
Please open a private security advisory on GitHub (**Security → Report a vulnerability**) or contact the repository owner directly. Do not open a public issue for security problems.
