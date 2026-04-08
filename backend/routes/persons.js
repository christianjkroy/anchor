import { Router } from 'express';
import { pool } from '../db/pool.js';
import { asyncHandler } from '../middleware/async_handler.js';
import {
  computeConsistencyScore,
  computeEnergyTrend,
  computeFollowThroughRate,
  computeInitiationRatio,
  computeRealityScore,
} from '../lib/relationship_metrics.js';

export const personsRouter = Router();

personsRouter.get('/', asyncHandler(async (req, res) => {
  const { rows } = await pool.query(
    `SELECT p.*,
       COUNT(i.id)::int AS total_interactions,
       MAX(i.created_at) AS last_interaction_at
     FROM persons p
     LEFT JOIN interactions i ON i.person_id = p.id
     WHERE p.user_id = $1
     GROUP BY p.id
     ORDER BY p.name`,
    [req.user.userId]
  );
  res.json(rows);
}));

personsRouter.post('/', asyncHandler(async (req, res) => {
  const { name, relationshipType, photoUrl } = req.body;
  if (!name) return res.status(400).json({ error: 'name required' });
  const { rows } = await pool.query(
    'INSERT INTO persons (user_id, name, relationship_type, photo_url) VALUES ($1,$2,$3,$4) RETURNING *',
    [req.user.userId, name, relationshipType ?? 'friend', photoUrl ?? null]
  );
  res.status(201).json(rows[0]);
}));

personsRouter.get('/:id', asyncHandler(async (req, res) => {
  const { rows } = await pool.query(
    'SELECT * FROM persons WHERE id = $1 AND user_id = $2',
    [req.params.id, req.user.userId]
  );
  if (!rows[0]) return res.status(404).json({ error: 'Not found' });
  res.json(rows[0]);
}));

personsRouter.patch('/:id', asyncHandler(async (req, res) => {
  const fields = [
    'name',
    'relationship_type',
    'photo_url',
    'perception_score',
    'reality_score',
    'initiation_ratio',
    'consistency_score',
  ];
  const updates = [];
  const values = [];
  let idx = 1;
  for (const field of fields) {
    const camel = field.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
    if (req.body[camel] !== undefined) {
      updates.push(`${field} = $${idx++}`);
      values.push(req.body[camel]);
    }
  }
  if (!updates.length) return res.status(400).json({ error: 'Nothing to update' });
  values.push(req.params.id, req.user.userId);
  const { rows } = await pool.query(
    `UPDATE persons SET ${updates.join(', ')} WHERE id = $${idx++} AND user_id = $${idx} RETURNING *`,
    values
  );
  if (!rows[0]) return res.status(404).json({ error: 'Not found' });
  res.json(rows[0]);
}));

personsRouter.delete('/:id', asyncHandler(async (req, res) => {
  const { rowCount } = await pool.query(
    'DELETE FROM persons WHERE id = $1 AND user_id = $2',
    [req.params.id, req.user.userId]
  );
  if (!rowCount) return res.status(404).json({ error: 'Not found' });
  res.status(204).end();
}));

// Stats endpoint — aggregates for a single person
personsRouter.get('/:id/stats', asyncHandler(async (req, res) => {
  const [person, interactions] = await Promise.all([
    pool.query('SELECT * FROM persons WHERE id = $1 AND user_id = $2', [req.params.id, req.user.userId]),
    pool.query(
      'SELECT * FROM interactions WHERE person_id = $1 AND user_id = $2 ORDER BY created_at DESC',
      [req.params.id, req.user.userId]
    ),
  ]);
  if (!person.rows[0]) return res.status(404).json({ error: 'Not found' });

  const all = interactions.rows;
  const initiationRatio = computeInitiationRatio(all);
  const consistencyScore = computeConsistencyScore(all);
  const energyTrend = computeEnergyTrend(all);
  const followThroughRate = computeFollowThroughRate(all);
  const realityScore = computeRealityScore({
    initiationRatio,
    consistencyScore,
    energyTrend,
    followThroughRate,
  });

  const sentimentCounts = { anxious: 0, secure: 0, avoidant: 0 };
  for (const i of all) {
    if (i.sentiment && sentimentCounts[i.sentiment] !== undefined) sentimentCounts[i.sentiment]++;
  }

  res.json({
    person: person.rows[0],
    totalInteractions: all.length,
    initiationRatio, // "they initiated" ratio
    consistencyScore,
    followThroughRate,
    energyTrend,
    realityScore,
    sentimentDistribution: sentimentCounts,
    lastInteractionAt: all[0]?.created_at ?? null,
  });
}));

// Relationship graph payload for Metal/React graph views
personsRouter.get('/graph/network', asyncHandler(async (req, res) => {
  const [persons, interactions] = await Promise.all([
    pool.query(
      `SELECT id, name, photo_url, initiation_ratio, consistency_score, perception_score, reality_score
       FROM persons WHERE user_id = $1 ORDER BY name`,
      [req.user.userId]
    ),
    pool.query(
      `SELECT person_id, type, energy_rating, created_at
       FROM interactions
       WHERE user_id = $1
       ORDER BY created_at DESC
       LIMIT 500`,
      [req.user.userId]
    ),
  ]);

  const interactionsByPerson = new Map();
  for (const row of interactions.rows) {
    if (!interactionsByPerson.has(row.person_id)) interactionsByPerson.set(row.person_id, []);
    interactionsByPerson.get(row.person_id).push(row);
  }

  const nodes = persons.rows.map((person) => {
    const personInteractions = interactionsByPerson.get(person.id) ?? [];
    const avgEnergy = personInteractions.length
      ? personInteractions.reduce((sum, i) => sum + (i.energy_rating ?? 0), 0) / personInteractions.length
      : 0;
    return {
      id: person.id,
      name: person.name,
      photoUrl: person.photo_url,
      interactionCount: personInteractions.length,
      avgEnergy,
      initiationRatio: person.initiation_ratio,
      consistencyScore: person.consistency_score,
      perceptionScore: person.perception_score,
      realityScore: person.reality_score,
    };
  });

  // Simple star topology around the user center.
  const edges = nodes.map((n) => ({
    source: 'self',
    target: n.id,
    weight: Math.min(1, Math.max(0.1, n.interactionCount / 20)),
    energy: n.avgEnergy ?? 0,
  }));

  res.json({
    generatedAt: new Date().toISOString(),
    nodes: [{ id: 'self', name: 'You', interactionCount: 0, avgEnergy: 0 }, ...nodes],
    edges,
  });
}));
