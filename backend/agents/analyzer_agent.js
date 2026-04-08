/**
 * Analyzer Agent (LangChain)
 *
 * Updates a person's profile after a new interaction. Recalculates initiation ratio,
 * energy trend, consistency score. Drafts potential insights. Has full DB access.
 */
import { ChatOpenAI } from '@langchain/openai';
import { HumanMessage, SystemMessage } from '@langchain/core/messages';
import { pool } from '../db/pool.js';
import { callRAnalysis } from '../analysis/r_client.js';
import {
  computeConsistencyScore,
  computeEnergyTrend,
  computeFollowThroughRate,
  computeInitiationRatio,
  computeRealityScore,
} from '../lib/relationship_metrics.js';

const llm = process.env.OPENAI_API_KEY
  ? new ChatOpenAI({ model: 'gpt-4o-mini', temperature: 0 })
  : null;

/**
 * @param {object} interaction - Interaction row from DB
 * @param {string} userId
 * @returns {{ updatedMetrics: object, draftInsights: Array }}
 */
export async function runAnalyzerAgent(interaction, userId) {
  const { person_id } = interaction;

  // Fetch full interaction history for this person
  const { rows: history } = await pool.query(
    `SELECT * FROM interactions
     WHERE person_id = $1 AND user_id = $2
     ORDER BY created_at DESC`,
    [person_id, userId]
  );

  if (history.length < 2) return { updatedMetrics: {}, draftInsights: [] };

  // Compute metrics locally first (fast path)
  const metrics = computeMetrics(history);

  // Call R for statistically-backed initiation confidence interval
  let initiationCI = null;
  try {
    initiationCI = await callRAnalysis('/initiation-analysis', {
      personId: person_id,
      userId,
    });
  } catch {
    // R unavailable — proceed without CI
  }

  // Update person record
  await pool.query(
    `UPDATE persons SET
       initiation_ratio = $1,
       consistency_score = $2,
       reality_score = $3
     WHERE id = $4`,
    [metrics.initiationRatio, metrics.consistencyScore, metrics.realityScore, person_id]
  );

  // Ask LLM to draft insights based on metrics
  const draftInsights = await draftInsightsWithLLM(interaction, history, metrics, initiationCI);

  return { updatedMetrics: metrics, draftInsights };
}

function computeMetrics(interactions) {
  const initiationRatio = computeInitiationRatio(interactions);
  const consistencyScore = computeConsistencyScore(interactions);
  const followThroughRate = computeFollowThroughRate(interactions);
  const energyTrend = computeEnergyTrend(interactions);
  const realityScore = computeRealityScore({
    initiationRatio,
    consistencyScore,
    followThroughRate,
    energyTrend,
  });

  const sentimentCounts = {};
  for (const i of interactions) {
    if (i.sentiment) sentimentCounts[i.sentiment] = (sentimentCounts[i.sentiment] ?? 0) + 1;
  }

  return {
    initiationRatio,
    consistencyScore,
    followThroughRate,
    energyTrend,
    realityScore,
    sentimentCounts,
    totalInteractions: interactions.length,
  };
}

async function draftInsightsWithLLM(interaction, history, metrics, initiationCI) {
  if (!llm) return [];

  const recentHistory = history.slice(0, 10);
  const prompt = `
You are analyzing relationship data for a personal tracking app.
Draft 0–2 potential insights based on this interaction and history.

New interaction:
- Type: ${interaction.type}
- Initiated by: ${interaction.initiated_by}
- Feeling before: ${interaction.feeling_before ?? 'unknown'}
- Feeling during: ${interaction.feeling_during ?? 'unknown'}
- Feeling after: ${interaction.feeling_after ?? 'unknown'}
- Sentiment: ${interaction.sentiment ?? 'unclassified'}
- Note: "${interaction.note}"

Computed metrics (last ${history.length} interactions):
- Initiation ratio (them): ${(metrics.initiationRatio * 100).toFixed(0)}%
- Consistency score: ${metrics.consistencyScore.toFixed(2)}
- Follow-through rate: ${(metrics.followThroughRate * 100).toFixed(0)}%
- Energy trend slope: ${metrics.energyTrend.toFixed(3)}
- Reality score: ${metrics.realityScore.toFixed(2)}
- Sentiment breakdown: ${JSON.stringify(metrics.sentimentCounts)}
${initiationCI ? `- R confidence interval: ${JSON.stringify(initiationCI)}` : ''}

Recent 10 interaction sentiments: ${recentHistory.map(i => i.sentiment ?? '?').join(', ')}

Return a JSON array of insight objects. Each must have:
- content (string): 1–2 sentence observation, written directly to the user
- pattern_type (string): one of: initiationImbalance, sentimentDrift, contextDependentBehavior, perceptionMismatch, energyPattern, general
- severity (string): low | medium | high
- needs_statistical_validation (boolean): true if this claim needs R validation before surfacing

Return [] if nothing noteworthy. Never invent patterns from sparse data (< 4 interactions).
`;

  try {
    const response = await llm.invoke([
      new SystemMessage('You return only valid JSON arrays. No prose.'),
      new HumanMessage(prompt),
    ]);
    const rawText = typeof response.content === 'string'
      ? response.content
      : JSON.stringify(response.content);
    const text = rawText.replace(/```json\n?|\n?```/g, '').trim();
    return JSON.parse(text);
  } catch {
    return [];
  }
}
