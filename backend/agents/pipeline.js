/**
 * Agent Pipeline Orchestrator
 *
 * Logger Agent (DSPy) → Analyzer Agent (LangChain) → Critic Agent (AutoGen)
 * Fires after each interaction is logged. Runs async, does not block the HTTP response.
 */
import { runLoggerAgent } from './logger_agent.js';
import { runAnalyzerAgent } from './analyzer_agent.js';
import { runCriticAgent } from './critic_agent.js';
import { pool } from '../db/pool.js';
import { createInteractionEmbedding, embeddingToSqlVector } from '../lib/embeddings.js';

export async function runAgentPipeline(interaction, userId) {
  try {
    // Step 1 — Logger Agent: enrich/validate the interaction
    const enriched = await runLoggerAgent({
      note: interaction.note,
      type: interaction.type,
      initiatedBy: interaction.initiated_by,
      feelingBefore: interaction.feeling_before,
      feelingDuring: interaction.feeling_during,
      feelingAfter: interaction.feeling_after,
    });

    // Persist enriched fields back to the interaction
    const embedding = await createInteractionEmbedding({
      note: enriched.note_clean ?? interaction.note,
      type: enriched.type ?? interaction.type,
      initiatedBy: enriched.initiated_by ?? interaction.initiated_by,
      feelingBefore: interaction.feeling_before,
      feelingDuring: interaction.feeling_during,
      feelingAfter: interaction.feeling_after,
      sentiment: enriched.sentiment,
    });

    await pool.query(
      `UPDATE interactions SET
         type = COALESCE($1, type),
         initiated_by = COALESCE($2, initiated_by),
         note = COALESCE(NULLIF($3, ''), note),
         duration_minutes = COALESCE($4, duration_minutes),
         sentiment = $5,
         sentiment_confidence = $6,
         energy_rating = COALESCE(energy_rating, $7),
         vibe_rating = COALESCE(vibe_rating, $8),
         embedding = COALESCE($9::vector, embedding)
       WHERE id = $10`,
      [
        enriched.type,
        enriched.initiated_by,
        enriched.note_clean ?? '',
        enriched.duration_minutes ?? null,
        enriched.sentiment ?? 'neutral',
        0.8,
        enriched.energy_rating,
        enriched.vibe_rating,
        embeddingToSqlVector(embedding),
        interaction.id,
      ]
    );
    interaction = { ...interaction, ...enriched };

    // Step 2 — Analyzer Agent: update person profile, draft insights
    const { draftInsights } = await runAnalyzerAgent(interaction, userId);

    if (!draftInsights.length) return;

    // Step 3 — Critic Agent: validate and approve
    const approvedInsights = await runCriticAgent(draftInsights, interaction.person_id, userId);

    // Persist approved insights
    for (const insight of approvedInsights) {
      await pool.query(
        `INSERT INTO insights (user_id, person_id, content, pattern_type, severity)
         VALUES ($1, $2, $3, $4, $5)`,
        [userId, interaction.person_id, insight.content, insight.pattern_type, insight.severity]
      );
    }

    if (approvedInsights.length) {
      console.log(`[pipeline] ${approvedInsights.length} insight(s) stored for interaction ${interaction.id}`);
    }
  } catch (err) {
    console.error('[pipeline] Error:', err.message);
  }
}
