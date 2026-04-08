import { Router } from 'express';
import { pool } from '../db/pool.js';
import { asyncHandler } from '../middleware/async_handler.js';

export const digestRouter = Router();

digestRouter.get('/', asyncHandler(async (req, res) => {
  const { rows } = await pool.query(
    'SELECT * FROM weekly_digests WHERE user_id = $1 ORDER BY week_start_date DESC LIMIT 12',
    [req.user.userId]
  );
  res.json(rows);
}));

digestRouter.get('/:id', asyncHandler(async (req, res) => {
  const { rows } = await pool.query(
    'SELECT * FROM weekly_digests WHERE id = $1 AND user_id = $2',
    [req.params.id, req.user.userId]
  );
  if (!rows[0]) return res.status(404).json({ error: 'Not found' });
  res.json(rows[0]);
}));

digestRouter.post('/generate', asyncHandler(async (req, res) => {
  const weekStart = req.body.weekStartDate ?? startOfWeekISO(new Date());

  const [interactions, insights] = await Promise.all([
    pool.query(
      `SELECT created_at, initiated_by, sentiment, energy_rating
       FROM interactions
       WHERE user_id = $1
         AND created_at >= $2::date
         AND created_at < ($2::date + INTERVAL '7 days')`,
      [req.user.userId, weekStart]
    ),
    pool.query(
      `SELECT content, generated_at
       FROM insights
       WHERE user_id = $1
         AND generated_at >= $2::date
         AND generated_at < ($2::date + INTERVAL '7 days')
       ORDER BY generated_at DESC`,
      [req.user.userId, weekStart]
    ),
  ]);

  const total = interactions.rows.length;
  const theyInitiated = interactions.rows.filter((i) => i.initiated_by === 'them').length;
  const avgEnergy = total
    ? interactions.rows.reduce((sum, i) => sum + (i.energy_rating ?? 0), 0) / total
    : 0;

  const narrative = [
    `You logged ${total} interaction${total === 1 ? '' : 's'} this week.`,
    `They initiated ${theyInitiated} (${total ? Math.round((theyInitiated / total) * 100) : 0}%).`,
    `Average energy was ${avgEnergy.toFixed(2)} on the -1 to 1 scale.`,
    insights.rows[0] ? `Top insight: ${insights.rows[0].content}` : 'No approved insights yet this week.',
  ].join(' ');

  const payload = {
    narrative,
    initiation_changes: {
      theyInitiated,
      total,
      ratio: total ? theyInitiated / total : 0.5,
    },
    patterns: {
      insightCount: insights.rows.length,
      topInsights: insights.rows.slice(0, 3).map((i) => i.content),
    },
  };

  const { rows } = await pool.query(
    `INSERT INTO weekly_digests
      (user_id, week_start_date, narrative, initiation_changes, patterns)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (user_id, week_start_date) DO UPDATE
       SET narrative = EXCLUDED.narrative,
           initiation_changes = EXCLUDED.initiation_changes,
           patterns = EXCLUDED.patterns,
           generated_at = NOW()
     RETURNING *`,
    [req.user.userId, weekStart, payload.narrative, payload.initiation_changes, payload.patterns]
  );

  res.status(201).json(rows[0]);
}));

function startOfWeekISO(date) {
  const day = date.getUTCDay();
  const diff = day === 0 ? -6 : 1 - day;
  const monday = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate() + diff));
  return monday.toISOString().slice(0, 10);
}
