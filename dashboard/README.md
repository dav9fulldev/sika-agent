# SIKA Pay web dashboard

Read-only dashboard built with [AG Studio](https://www.ag-grid.com/studio/), served by the backend at `/dashboard/`.

- **Sign-in:** the app (Settings → Web dashboard) shows a single-use code (10 minutes). `POST /api/v1/dashboard/session` exchanges it for a token that only the dashboard routes accept.
- **Data:** `GET /api/v1/dashboard/data`: payments, followed products, price changes, subscriptions and the SIKA authorization of the signed-in user.
- **AI:** Studio Agent Framework. A SIKA agent leads and delegates page work to Studio's built-in agents; every model turn goes through `POST /api/v1/dashboard/llm` (Gemini on Vertex AI). No model key in the browser.
- **Licence:** the AG Studio key comes from the backend (`AG_STUDIO_LICENSE` in Secret Manager). Without it, Studio runs with a trial watermark.

```bash
npm ci
npm run dev     # http://localhost:5173/dashboard/, API proxied to http://localhost:8001
npm run lint
npm run build   # dist/, copied to backend/static/dashboard by the deploy workflow
```
