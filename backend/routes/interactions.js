import { Router } from 'express';
import { pool } from '../db/pool.js';
import { runAgentPipeline } from '../agents/pipeline.js';
import { asyncHandler } from '../middleware/async_handler.js';

export const interactionsRouter = Router();

interactionsRouter.get('/', asyncHandler(async (req, res) => {
  const { personId, limit = 50, offset = 0 } = req.query;
  let query = 'SELECT i.*, p.name AS person_name FROM interactions i JOIN persons p ON p.id = i.person_id WHERE i.user_id = $1';
  const values = [req.user.userId];
  if (personId) {
    query += ` AND i.person_id = $${values.length + 1}`;
    values.push(personId);
  }
  query += ` ORDER BY i.created_at DESC LIMIT $${values.length + 1} OFFSET $${values.length + 2}`;
  values.push(Number(limit), Number(offset));
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
     feelingAfter ?? null, locationContext ?? null, durationMinutes ?? null,
     energyRating ?? null, vibeRating ?? null, note ?? '']
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
  const { embedding, limit = 10 } = req.body;
  if (!Array.isArray(embedding)) return res.status(400).json({ error: 'embedding array required' });
  const { rows } = await pool.query(
    `SELECT i.*, p.name AS person_name,
            (embedding <=> $1::vector) AS distance
     FROM interactions i
     JOIN persons p ON p.id = i.person_id
     WHERE i.user_id = $2 AND i.embedding IS NOT NULL
     ORDER BY distance ASC
     LIMIT $3`,
    [`[${embedding.join(',')}]`, req.user.userId, Number(limit)]
  );
  res.json(rows);
}));
