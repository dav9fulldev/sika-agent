# SIKA Pay — Demo Video Script (target 155 s, hard limit < 3:00)

Recorded on an **Android phone** with screen capture, plus a small picture-in-picture of the presenter if wanted. Everything shown must be real: real Gemini answers and real PayPal **sandbox** statuses. If a take fails, re-record; never fake a screen.

**No third-party logos or music without permission.** The PayPal name is used in text only, and the sandbox checkout page is PayPal's own UI. Use royalty-free music or none.

Prerequisites: [DEMO_CHECKLIST.md](DEMO_CHECKLIST.md).

---

| # | Time | On screen | Action | English voice-over | On-screen text | Expected result | Fallback if it fails |
|---|---|---|---|---|---|---|---|
| 1 | 0:00–0:12 | SIKA Pay home: "Hello Ama 👋", PayPal card, SANDBOX badge | None (slow scroll) | "AI assistants are starting to spend our money. But would you let one pay without knowing what it picked, what it costs, or whether it really paid?" | **SIKA Pay** — Your AI. Your money. Your control. | Home loads, "Connected to sandbox" in green | If the status is red, the backend is unreachable: fix `PUBLIC_BASE_URL`/IP and retake |
| 2 | 0:12–0:27 | Same screen → tap **Assisted buy** / open Assistant | Tap the PayPal card | "SIKA Pay is a personal payment agent built on PayPal. You say what you want. It checks, prepares, and you stay in control of every step." | Gemini · PayPal Orders v2 · Sandbox | Chat opens | – |
| 3 | 0:27–0:55 | Chat: user types or says *"Help me buy an Excel course without going over 50 dollars."* | Send the message | "I ask for an Excel course, with a 50-dollar budget. Gemini searches the store catalog with a tool, picks the course that matches, and asks the backend to prepare a checkout. The AI never sets the price: the server does, and it checks my budget." | Agent steps: *Searching the catalog → Checking budget & preparing PayPal checkout* | Agent steps appear, then an explanation and the checkout card: Excel course, **49.00 USD**, "Within your 50 USD budget · 1.00 left" | If Gemini returns 429, the reply is labelled local fallback: wait about 1 min and retake (keep the AI version for the video) |
| 4 | 0:55–1:10 | (Optional) user: *"Actually, the marketing course."* | Send | "If I change my mind and ask for something over budget, SIKA refuses and explains, with alternatives that fit." | Budget guard | "64.00 USD is above your 50 USD budget" + alternatives; no card | Skip this scene if time is short |
| 5 | 1:10–1:30 | Tap **Review and pay** → payment details screen | Scroll slowly, open **"What SIKA verified"** | "Before anything happens, I review the details. SIKA separates what is verified (catalog price, backend total) from what I said: my budget. Nothing has been charged, and no PayPal order exists yet." | Verified · Provided by you · Assumptions | Details: price, quantity, known fees, total, payee "SIKA Demo Store (sandbox)" | – |
| 6 | 1:30–1:45 | Tap **Confirm and pay with PayPal** → fingerprint → PayPal sandbox page | Authenticate, then log in with the sandbox buyer | "I confirm with my fingerprint. Only now does the backend create a real PayPal sandbox order, and I approve it on PayPal." | Order created on PayPal (sandbox) | PayPal sandbox login/approval page opens in the browser | If the browser doesn't open: tap **Open PayPal**. If login is slow, cut during editing |
| 7 | 1:45–2:05 | Back in SIKA: stepper "Approved on PayPal" → **Pay 49.00 USD now** | Approve on PayPal, return to the app, tap Pay | "Back in SIKA, the backend asks PayPal directly whether the order is approved. Only then can I complete the payment. The capture uses an idempotency key, so even a double tap can never charge twice." | Created ✓ Approved ✓ → Capture | Stepper moves to "Approved"; then the capture | If still "Awaiting PayPal", tap "I've approved — check" |
| 8 | 2:05–2:25 | Result: "Payment captured!", captured amount, capture status COMPLETED, order ID, capture ID; chat message from SIKA | Tap **View details** (audit trail) | "This is PayPal's real answer: the order and capture IDs and the captured amount. SIKA explains the result and keeps an audit trail of every step." | Real status returned by PayPal | Receipt with IDs; audit trail sheet | – |
| 9 | 2:25–2:40 | Transactions tab (history) → back to home | Tap Transactions | "SIKA Pay helps people buy with confidence, especially first-time digital payers: an agent that explains, checks and asks before money moves." | Built with Flutter · FastAPI · Gemini · PayPal | History shows the completed checkout | – |

**Total: about 2:40 for the full version, about 2:25 without scene 4.**

### Editing notes
- Speed up the PayPal login and network waits (×2 to ×4) and mention it in a caption ("sped up").
- Keep the **SANDBOX** badge visible at least once per scene.
- Hide personal data. Do not show the `.env` file or any terminal containing secrets.
- English captions for the entire voice-over (accessibility, and the rules require English).

### Upload checklist (YouTube)
- Public visibility, title: *SIKA Pay — an AI payment agent with PayPal (PayPal AI Hackathon 2026)*.
- Description: repo link, one sentence per tool used (Gemini, PayPal Orders v2 sandbox).
- Length strictly under 3:00.
