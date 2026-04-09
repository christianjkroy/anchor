import { Router } from 'express';
import { pool } from '../db/pool.js';
import { runAgentPipeline } from '../agents/pipeline.js';
import { asyncHandler } from '../middleware/async_handler.js';
import { createInteractionEmbedding, embeddingToSqlVector } from '../lib/embeddings.js';

export const interactionsRouter = Router();

interactionsRouter.get('/', asyncHandler(async (req, res) => {
  const { personId } = req.query;
  const limit = clampInteger(req.query.limit, 50, { min: 1, max: 200 });
  const offset = clampInteger(req.query.offset, 0, { min: 0, max: 5000 });
  let query = 'SELECT i.*, p.name AS person_name FROM interactions i JOIN persons p ON p.id = i.person_id WHERE i.user_id = $1';
  const values = [req.user.userId];
  if (personId) {
    query += ` AND i.person_id = $${values.length + 1}`;
    values.push(personId);
  }
  query += ` ORDER BY i.created_at DESC LIMIT $${values.length + 1} OFFSET $${values.length + 2}`;
  values.push(limit, offset);
  const { rows } = await pool.query(query, values);
  res.json(rows);
}));

interactionsRouter.post('/', asyncHandler(async (req, res) => {
  const {
    personId, type, initiatedBy, feelingBefore, feelingDuring, feelingAfter,
    locationContext, durationMinutes, energyRating, vibeRating, note,
  } = req.body;
  if (!personId) {
    return res.status(400).json({ error: 'personId required' });
  }

  const finalType = type ?? 'text';
  const finalInitiatedBy = initiatedBy ?? 'unclear';
  const validType = ['text', 'hangout', 'call', 'group'];
  const validInitiatedBy = ['user', 'them', 'unclear'];
  if (!validType.includes(finalType)) return res.status(400).json({ error: 'invalid type' });
  if (!validInitiatedBy.includes(finalInitiatedBy)) return res.status(400).json({ error: 'invalid initiatedBy' });

  const normalizedEnergyRating = normalizeOptionalScore(energyRating, { min: -1, max: 1, field: 'energyRating' });
  const normalizedVibeRating = normalizeOptionalScore(vibeRating, { min: -1, max: 1, field: 'vibeRating' });
  const normalizedDuration = normalizeOptionalInteger(durationMinutes, { min: 0, max: 24 * 60, field: 'durationMinutes' });

  // Verify person belongs to user
  const personCheck = await pool.query('SELECT id FROM persons WHERE id = $1 AND user_id = $2', [personId, req.user.userId]);
  if (!personCheck.rows[0]) return res.status(404).json({ error: 'Person not found' });

  const { rows } = await pool.query(
    `INSERT INTO interactions
       (user_id, person_id, type, initiated_by, feeling_before, feeling_during, feeling_after,
        location_context, duration_minutes, energy_rating, vibe_rating, note)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
     RETURNING *`,
    [req.user.userId, personId, finalType, finalInitiatedBy, feelingBefore ?? null, feelingDuring ?? null,
     feelingAfter ?? null, locationContext ?? null, normalizedDuration,
     normalizedEnergyRating, normalizedVibeRating, typeof note === 'string' ? note.trim() : '']
  );
  const interaction = rows[0];

  // Run agent pipeline async — don't block response
  runAgentPipeline(interaction, req.user.userId).catch(err =>
    console.error('Agent pipeline error:', err.message)
  );

  res.status(201).json(interaction);
}));

interactionsRouter.get('/:id', asyncHandler(async (req, res) => {
  const { rows } = await pool.query(
    'SELECT * FROM interactions WHERE id = $1 AND user_id = $2',
    [req.params.id, req.user.userId]
  );
  if (!rows[0]) return res.status(404).json({ error: 'Not found' });
  res.json(rows[0]);
}));

interactionsRouter.delete('/:id', asyncHandler(async (req, res) => {
  const { rowCount } = await pool.query(
    'DELETE FROM interactions WHERE id = $1 AND user_id = $2',
    [req.params.id, req.user.userId]
  );
  if (!rowCount) return res.status(404).json({ error: 'Not found' });
  res.status(204).end();
}));

// Semantic search via pgvector
interactionsRouter.post('/search', asyncHandler(async (req, res) => {
  const { embedding, query, limit = 10 } = req.body;
  const normalizedLimit = clampInteger(limit, 10, { min: 1, max: 50 });
  let searchEmbedding = embedding;

  if (!Array.isArray(searchEmbedding)) {
    if (!query || typeof query !== 'string' || !query.trim()) {
      return res.status(400).json({ error: 'embedding array or query string required' });
    }
    searchEmbedding = await createInteractionEmbedding(query);
  }

  const { rows } = await pool.query(
    `SELECT i.*, p.name AS person_name,
            (embedding <=> $1::vector) AS distance
     FROM interactions i
     JOIN persons p ON p.id = i.person_id
     WHERE i.user_id = $2 AND i.embedding IS NOT NULL
     ORDER BY distance ASC
     LIMIT $3`,
    [embeddingToSqlVector(searchEmbedding), req.user.userId, normalizedLimit]
  );
  res.json(rows);
}));

function clampInteger(value, fallback, { min, max }) {
  const parsed = Number.parseInt(value ?? fallback, 10);
  if (Number.isNaN(parsed)) return fallback;
  return Math.max(min, Math.min(max, parsed));
}

function normalizeOptionalScore(value, { min, max, field }) {
  if (value === undefined || value === null || value === '') return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < min || parsed > max) {
    const error = new Error(`${field} must be between ${min} and ${max}`);
    error.statusCode = 400;
    throw error;
  }
  return parsed;
}

function normalizeOptionalInteger(value, { min, max, field }) {
  if (value === undefined || value === null || value === '') return null;
  const parsed = Number.parseInt(value, 10);
  if (Number.isNaN(parsed) || parsed < min || parsed > max) {
    const error = new Error(`${field} must be between ${min} and ${max}`);
    error.statusCode = 400;
    throw error;
  }
  return parsed;
}
