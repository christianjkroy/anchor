# Anchor

Anchor is a relationship intelligence system that helps compare anxious perception to behavioral reality.

## Stack

- iOS: SwiftUI + Metal + Core ML
- Backend: Node.js + PostgreSQL + pgvector
- Agent pipeline: Logger -> Analyzer -> Critic
- Analysis: R Plumber API
- Web dashboard: React + CSS
- Training: Hugging Face + CUDA + MLX + Core ML export scripts

## Repository Layout

- `Anchor/` iOS app code
- `backend/` Node API, SQL migrations, agents, R integration
- `web/` React dashboard
- `training/` model fine-tuning + validation + Core ML conversion scripts

## Quick Start

1. Start PostgreSQL (pgvector included):
   - `docker compose up -d postgres`
2. Configure backend env:
   - copy `backend/.env.example` to `backend/.env`
3. Run backend migration and API:
   - `cd backend`
   - `npm install`
   - `npm run migrate`
   - `npm run start`
4. Run R analysis API (optional but recommended):
   - `cd backend`
   - `Rscript analysis/plumber_server.R`
5. Run web dashboard:
   - `cd web`
   - `npm install`
   - `npm run dev`

## Project Status

- The React dashboard and Node API are intended to run together locally, with the backend serving the built dashboard in production.
- OpenAI and the R analysis service are optional. If they are not configured, the app falls back to deterministic local logic for logging and perception scoring.
- Before committing, make sure generated folders like `node_modules/`, `web/dist/`, `.venv/`, and `__pycache__/` are not tracked.

## Notes

- If `OPENAI_API_KEY` is not set, the backend still works with deterministic fallback logic.
- The agent pipeline runs asynchronously after interaction creation.
- `weekly_digests` supports upsert by `(user_id, week_start_date)`.
- R analysis requires an installed R runtime with `plumber` and `jsonlite` (and optionally `DBI` + `RPostgres`).
