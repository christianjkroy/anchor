# Anchor

Anchor is a relationship intelligence app that tracks your interactions, detects recurring behavioral patterns, and surfaces the gap between how you perceive a relationship and how you actually behave in it.

Log an interaction, note how you felt before, during, and after — Anchor does the rest: sentiment analysis, pattern detection, and weekly digests that synthesize what the data actually says.

## What it does

- **Interaction logging** — record who, what type, who initiated, feelings across three stages, duration, location, and notes
- **Sentiment analysis** — on-device classification maps feeling signals to secure / anxious / avoidant with confidence scores
- **Pattern detection** — surfaces initiation imbalance, sentiment drift, context-dependent behavior, and perception mismatches (requires ≥ 4 interactions)
- **Metal relationship graph** — force-directed simulation at 60 fps; pan, zoom, tap, and long-press to explore your network
- **Weekly digests** — generated via Apple Foundation Models (iOS 26+) with a rich template fallback, fired on Sundays
- **Cloud sync** — optional Supabase backend with end-to-end encryption
- **Backend enrichment** — async sentiment labeling, pgvector embeddings for semantic search, and LLM-powered digest generation via Ollama
- **Web dashboard** — React + Vite view of relationship data synced to the backend
- **R analysis** — Plumber service for perception checks and clustering

## Architecture

| Layer | Stack |
|---|---|
| iOS app | SwiftUI · SwiftData · Metal · Apple Foundation Models |
| Backend API | Node.js · Express · PostgreSQL · pgvector |
| LLM pipeline | Ollama (local) — logger → analyzer → critic |
| Statistical analysis | R · Plumber |
| Web dashboard | React · Vite |
| Training utilities | Hugging Face · MLX · Core ML export |

## Repository layout

```
Anchor/       iOS application (SwiftUI + SwiftData + Metal)
backend/      API server, migrations, agents, embeddings, R integration
web/          Browser-based relationship dashboard
training/     Model fine-tuning, validation, and Core ML export scripts
```

## Quick start (full stack)

**Prerequisites:** Docker, Node.js, Ollama, R, Xcode 26+

```bash
# 1. Start PostgreSQL
docker compose up -d postgres

# 2. Configure backend
cp backend/.env.example backend/.env   # fill in values

# 3. Pull Ollama models
ollama pull llama3.2
ollama pull all-minilm

# 4. Start the backend
cd backend && npm install && npm run migrate && npm run start

# 5. Start the R analysis service (separate terminal)
cd backend && Rscript analysis/plumber_server.R

# 6. Start the web dashboard (separate terminal)
cd web && npm install && npm run dev

# 7. Open the iOS app
open Anchor/Anchor.xcodeproj
```

## iOS only (no backend required)

The iOS app is fully self-contained. On-device analysis runs without a server — just open `Anchor/Anchor.xcodeproj` in Xcode and run on a device or simulator. Cloud sync and backend enrichment are opt-in.

## Backend configuration

| Variable | Purpose |
|---|---|
| `LLM_PROVIDER` | `ollama` or `openai` (default: `openai`) |
| `OPENAI_API_KEY` | Required when `LLM_PROVIDER=openai` |
| `OPENAI_CHAT_MODEL` | Default: `gpt-4o-mini` |
| `OPENAI_EMBEDDING_MODEL` | Default: `text-embedding-3-small` |
| `OLLAMA_BASE_URL` | URL of your Ollama instance |
| `OLLAMA_CHAT_MODEL` | Default: `llama3.2` |
| `OLLAMA_EMBEDDING_MODEL` | Default: `all-minilm` |
| `R_PLUMBER_URL` | Enables R-backed perception and clustering analysis |
| `JWT_SECRET` | Auth token signing key |

`GET /health` reports the status of the backend, LLM, Ollama, and R services.

## Notes

- Interaction enrichment (sentiment + embeddings) runs asynchronously after creation.
- Weekly digests upsert by `(user_id, week_start_date)`.
- R analysis requires the `plumber` and `jsonlite` packages; `DBI` and `RPostgres` are recommended for database-backed analysis.
- `ClaudeService.swift` is named for a prior approach — it now runs fully on-device via rule-based logic and Apple Foundation Models with no external API calls.
