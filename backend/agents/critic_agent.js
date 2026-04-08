/**
 * Critic Agent (AutoGen-style)
 *
 * Validates draft insights from the Analyzer. Refuses to surface claims without
 * statistical backing. Calls R analysis layer for significance tests.
 */
import OpenAI from 'openai';
import { pool } from '../db/pool.js';
import { callRAnalysis } from '../analysis/r_client.js';

const client = process.env.OPENAI_API_KEY
  ? new OpenAI({ apiKey: process.env.OPENAI_API_KEY })
  : null;

const CRITIQUE_SCHEMA = {
  name: 'critique_insights',
  description: 'Review each draft insight and decide whether to approve, reject, or modify it',
  parameters: {
    type: 'object',
    required: ['decisions'],
    properties: {
      decisions: {
        type: 'array',
        items: {
          type: 'object',
          required: ['index', 'verdict', 'reason'],
          properties: {
            index: { type: 'integer' },
            verdict: { type: 'string', enum: ['approve', 'reject', 'modify'] },
            reason: { type: 'string' },
            modified_content: { type: 'string', description: 'Required when verdict is modify' },
          },
        },
      },
    },
  },
};

/**
 * @param {Array} draftInsights - From analyzer_agent
 * @param {string} personId
 * @param {string} userId
 * @returns {Array} Approved insights ready for DB insertion
 */
export async function runCriticAgent(draftInsights, personId, userId) {
  if (!draftInsights.length) return [];

  const indexedInsights = draftInsights.map((insight, index) => ({ ...insight, index }));
  const needsValidation = indexedInsights.filter((i) => i.needs_statistical_validation);
  const validationResults = await runStatisticalValidation(needsValidation, personId, userId);

  // Build critique context
  const enrichedInsights = indexedInsights.map((insight, idx) => {
    const validation = validationResults[idx] ?? null;
    return {
      ...insight,
      index: idx,
      statistical_result: validation,
    };
  });

  const { rows: history } = await pool.query(
    'SELECT COUNT(*)::int AS count FROM interactions WHERE person_id = $1 AND user_id = $2',
    [personId, userId]
  );
  const totalInteractions = history[0]?.count ?? 0;

  let decisions = [];
  if (client) {
    const response = await client.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: `You are a rigorous critic for a relationship analytics app.
Rules:
1. Reject any claim about a person with fewer than 4 interactions total.
2. Reject statistically unvalidated claims flagged as needing validation.
3. Reject absolute language ("always", "never") unless statistically proven.
4. Soften valid insights that are overly alarming without cause.
5. Approve specific, well-supported observations.

Total interactions with this person: ${totalInteractions}`,
        },
        {
          role: 'user',
          content: `Draft insights:\n${JSON.stringify(enrichedInsights, null, 2)}`,
        },
      ],
      tools: [{ type: 'function', function: CRITIQUE_SCHEMA }],
      tool_choice: { type: 'function', function: { name: 'critique_insights' } },
      temperature: 0,
    });
    const toolCall = response.choices[0].message.tool_calls?.[0];
    if (!toolCall) return [];
    const parsed = JSON.parse(toolCall.function.arguments);
    decisions = parsed.decisions ?? [];
  } else {
    decisions = indexedInsights.map((insight) => {
      const validation = validationResults[insight.index];
      const hasStats = !insight.needs_statistical_validation || Boolean(validation?.validated);
      if (totalInteractions < 4 || !hasStats) {
        return { index: insight.index, verdict: 'reject', reason: 'insufficient statistical support' };
      }
      return { index: insight.index, verdict: 'approve', reason: 'passes baseline checks' };
    });
  }

  const approved = [];

  for (const decision of decisions) {
    if (decision.verdict === 'reject') continue;
    const original = draftInsights[decision.index];
    if (!original) continue;
    approved.push({
      content: decision.verdict === 'modify' ? decision.modified_content : original.content,
      pattern_type: original.pattern_type,
      severity: original.severity,
    });
  }

  return approved;
}

async function runStatisticalValidation(insights, personId, userId) {
  if (!insights.length) return {};
  const results = {};

  for (const insight of insights) {
    try {
      if (insight.pattern_type === 'initiationImbalance') {
        results[insight.index] = await callRAnalysis('/initiation-analysis', { personId, userId });
      } else if (insight.pattern_type === 'energyPattern') {
        results[insight.index] = await callRAnalysis('/energy-clustering', { userId });
      } else if (insight.pattern_type === 'perceptionMismatch') {
        results[insight.index] = await callRAnalysis('/perception-divergence', {
          personId,
          userId,
        });
      } else {
        results[insight.index] = { validated: true, reason: 'no statistical gate required for this pattern' };
      }
    } catch {
      results[insight.index] = { error: 'R unavailable', validated: false };
    }
  }

  return results;
}
