import { Router } from 'express';
import { pool } from '../db/pool.js';
import { callRAnalysis } from '../analysis/r_client.js';
import { asyncHandler } from '../middleware/async_handler.js';
import {
  computeConsistencyScore,
  computeDivergence,
  computeEnergyTrend,
  computeFollowThroughRate,
  computeInitiationRatio,
  computeRealityScore,
} from '../lib/relationship_metrics.js';

export const perceptionRouter = Router();

perceptionRouter.get('/', asyncHandler(async (req, res) => {
  const { rows } = await pool.query(
    `SELECT pc.*, p.name AS person_name
     FROM perception_checks pc
     JOIN persons p ON p.id = pc.person_id
     WHERE pc.user_id = $1
     ORDER BY pc.checked_at DESC LIMIT 50`,
    [req.user.userId]
  );
  res.json(rows);
}));

perceptionRouter.post('/', asyncHandler(async (req, res) => {
  const { personId, perceivedScore } = req.body;
  if (!personId || perceivedScore === undefined) {
    return res.status(400).json({ error: 'personId and perceivedScore required' });
  }
  if (Number(perceivedScore) < 1 || Number(perceivedScore) > 5) {
    return res.status(400).json({ error: 'perceivedScore must be between 1 and 5' });
  }

  const { rows: personRows } = await pool.query(
    'SELECT id FROM persons WHERE id = $1 AND user_id = $2',
    [personId, req.user.userId]
  );
  if (!personRows[0]) return res.status(404).json({ error: 'Person not found' });

  // Pull behavioral metrics for reality score
  const { rows: interactions } = await pool.query(
    `SELECT initiated_by, feeling_after, sentiment, energy_rating
     FROM interactions
     WHERE person_id = $1 AND user_id = $2
     ORDER BY created_at DESC
     LIMIT 30`,
    [personId, req.user.userId]
  );

  const initiationRatio = computeInitiationRatio(interactions);
  const consistencyScore = computeConsistencyScore(interactions);
  const followThroughRate = computeFollowThroughRate(interactions);
  const energyTrend = computeEnergyTrend(interactions);
  const localRealityScore = computeRealityScore({
    initiationRatio,
    consistencyScore,
    followThroughRate,
    energyTrend,
  });

  const total = interactions.length;
  const realityMetrics = {
    initiationRatio,
    consistencyScore,
    followThroughRate,
    energyTrend,
    localRealityScore,
    totalInteractions: total,
  };

  // R analysis for perception divergence
  let divergenceResult = null;
  try {
    divergenceResult = await callRAnalysis('/perception-divergence', {
      perceived: perceivedScore,
      realityMetrics,
    });
  } catch {
    // Compute locally if R is unavailable
    divergenceResult = {
      reality_score: localRealityScore,
      divergence: computeDivergence(perceivedScore, localRealityScore),
      direction: perceivedScore < localRealityScore ? 'underestimating' : 'overestimating',
    };
  }

  const flagged = divergenceResult.divergence > 1.5;

  const { rows } = await pool.query(
    `INSERT INTO perception_checks
       (user_id, person_id, perceived_score, reality_score, divergence, direction, flagged)
     VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
    [req.user.userId, personId, perceivedScore,
     divergenceResult.reality_score, divergenceResult.divergence,
     divergenceResult.direction, flagged]
  );

  // Update person's cached scores
  await pool.query(
    'UPDATE persons SET perception_score = $1, reality_score = $2 WHERE id = $3',
    [perceivedScore, divergenceResult.reality_score, personId]
  );

  res.status(201).json({ ...rows[0], flagged });
}));

perceptionRouter.get('/person/:personId', asyncHandler(async (req, res) => {
  const { rows } = await pool.query(
    `SELECT * FROM perception_checks
     WHERE person_id = $1 AND user_id = $2
     ORDER BY checked_at DESC LIMIT 20`,
    [req.params.personId, req.user.userId]
  );
  res.json(rows);
}));
