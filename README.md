# Anchor

Anchor is a relationship intelligence app for tracking interactions, spotting recurring patterns, and comparing perception against behavioral reality across iOS, backend, web, and analysis workflows.

## Core Capabilities

- Log people and interactions from the iOS app
- Sync people and interactions to a Node.js API
- Enrich interactions asynchronously with sentiment labels and embeddings
- Generate perception checks and weekly digests
- Review relationship data in a lightweight web dashboard
- Experiment with local training and export workflows for sentiment models

## Architecture

- iOS app: SwiftUI + SwiftData + on-device analysis + Foundation Models fallback
- Backend API: Node.js + Express + PostgreSQL + pgvector
- LLM pipeline: logger, analyzer, and critic stages using local Ollama
- Statistical analysis: R Plumber service
- Web dashboard: React + Vite
- Training utilities: Hugging Face, CUDA, MLX, and Core ML export scripts

## Repository Layout

- `Anchor/`: iOS application and project files
- `backend/`: API server, migrations, agents, embeddings, and R integration
- `web/`: browser-based relationship dashboard
- `training/`: model fine-tuning, validation, export, and conversion scripts

## Quick Start

1. Start PostgreSQL:
   - `docker compose up -d postgres`
2. Configure backend environment:
   - copy `backend/.env.example` to `backend/.env`
3. Start Ollama and pull models:
   - `ollama pull qwen3:8b`
   - `ollama pull all-minilm`
4. Start the backend:
   - `cd backend`
   - `npm install`
   - `npm run migrate`
   - `npm run start`
5. Start the R analysis service:
   - `cd backend`
   - `Rscript analysis/plumber_server.R`
6. Start the web dashboard:
   - `cd web`
   - `npm install`
   - `npm run dev`
7. Open the iOS app in Xcode:
   - `open Anchor/Anchor.xcodeproj`

## Service Configuration

- `LLM_PROVIDER`: keep this set to `ollama` for the local setup
- `OLLAMA_BASE_URL`, `OLLAMA_CHAT_MODEL`, `OLLAMA_EMBEDDING_MODEL`: point the backend at a local Ollama instance
- `R_PLUMBER_URL`: enables R-backed perception and clustering analysis
- `GET /health`: reports configured backend, LLM, Ollama, and R service status

OpenAI is still supported as an optional provider, but it is not part of the default local setup.

## Notes

- Interaction enrichment runs asynchronously after interaction creation.
- Embeddings are stored in PostgreSQL with `pgvector` for semantic search.
- Weekly digests support upsert by `(user_id, week_start_date)`.
- R analysis requires `plumber` and `jsonlite`, with `DBI` and `RPostgres` recommended for database-backed analysis.
- Generated folders such as `node_modules/`, `web/dist/`, `.venv/`, and `__pycache__/` should remain untracked.
