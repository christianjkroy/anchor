# Anchor

Anchor is a relationship intelligence system for logging interactions, measuring relationship patterns, and comparing anxious perception to behavioral reality across iOS, backend, web, and model-training workflows.

## What It Does

- Log people and interactions from the iOS app
- Track relationship metrics like initiation ratio, consistency, and reality score
- Run an asynchronous insight pipeline with logger, analyzer, and critic stages
- Generate weekly digests and perception checks
- Support a lightweight web dashboard for reviewing relationship data
- Provide training and export scripts for experimentation with local sentiment models

## Stack

- iOS: SwiftUI + Metal + Core ML
- Backend: Node.js + PostgreSQL + pgvector
- Agent pipeline: Logger -> Analyzer -> Critic
- Analysis: R Plumber API
- Web dashboard: React + CSS
- Training: Hugging Face + CUDA + MLX + Core ML export scripts

## Repository Layout

- `Anchor/`: iOS app code
- `backend/`: Node API, SQL migrations, agents, and R integration
- `web/`: React dashboard
- `training/`: model fine-tuning, export, validation, and Core ML conversion scripts

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

## Optional Services

- `OPENAI_API_KEY`: enables richer agent behavior for the logger, analyzer, and critic pipeline
- `R_PLUMBER_URL`: enables R-backed perception and statistical analysis
- Without those services configured, the backend falls back to deterministic local logic where possible

## Notes

- The agent pipeline runs asynchronously after interaction creation.
- `weekly_digests` supports upsert by `(user_id, week_start_date)`.
- R analysis requires an installed R runtime with `plumber` and `jsonlite` (and optionally `DBI` + `RPostgres`).
- Generated folders like `node_modules/`, `web/dist/`, `.venv/`, and `__pycache__/` should remain untracked.
