import { Router } from 'express';
import { pool } from '../db/pool.js';
import { asyncHandler } from '../middleware/async_handler.js';

export const insightsRouter = Router();

insightsRouter.get('/', asyncHandler(async (req, res) => {
  const { personId, limit = 20 } = req.query;
  let query = 'SELECT i.*, p.name AS person_name FROM insights i LEFT JOIN persons p ON p.id = i.person_id WHERE i.user_id = $1';
  const values = [req.user.userId];
  if (personId) {
    query += ` AND i.person_id = $${values.length + 1}`;
    values.push(personId);
  }
  query += ` ORDER BY i.generated_at DESC LIMIT $${values.length + 1}`;
  values.push(Number(limit));
  const { rows } = await pool.query(query, values);
  res.json(rows);
}));

insightsRouter.post('/', asyncHandler(async (req, res) => {
  const { personId, content, patternType, severity, supportingInteractionIds } = req.body;
  if (!content) return res.status(400).json({ error: 'content required' });
  const { rows } = await pool.query(
    `INSERT INTO insights (user_id, person_id, content, pattern_type, severity, supporting_interaction_ids)
     VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
    [req.user.userId, personId ?? null, content, patternType ?? null, severity ?? null, supportingInteractionIds ?? null]
  );
  res.status(201).json(rows[0]);
}));

insightsRouter.delete('/:id', asyncHandler(async (req, res) => {
  const { rowCount } = await pool.query(
    'DELETE FROM insights WHERE id = $1 AND user_id = $2',
    [req.params.id, req.user.userId]
  );
  if (!rowCount) return res.status(404).json({ error: 'Not found' });
  res.status(204).end();
}));
