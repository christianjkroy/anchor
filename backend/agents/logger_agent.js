/**
 * Logger Agent (DSPy-style structured extraction)
 *
 * Takes raw interaction input and returns a validated, typed interaction object.
 * Uses OpenAI function calling for reliable JSON output — same principle as DSPy signatures.
 */
import OpenAI from 'openai';

const client = process.env.OPENAI_API_KEY
  ? new OpenAI({ apiKey: process.env.OPENAI_API_KEY })
  : null;

const INTERACTION_SCHEMA = {
  name: 'structure_interaction',
  description: 'Parse a raw interaction description into typed fields',
  parameters: {
    type: 'object',
    required: ['type', 'initiated_by', 'energy_rating', 'vibe_rating', 'sentiment', 'note_clean'],
    properties: {
      type: {
        type: 'string',
        enum: ['text', 'hangout', 'call', 'group'],
        description: 'Type of interaction',
      },
      initiated_by: {
        type: 'string',
        enum: ['user', 'them', 'unclear'],
      },
      energy_rating: {
        type: 'number',
        description: '-1.0 (very drained) to 1.0 (very energized)',
      },
      vibe_rating: {
        type: 'number',
        description: '-1.0 (very awkward) to 1.0 (very natural)',
      },
      sentiment: {
        type: 'string',
        enum: ['anxious', 'secure', 'avoidant', 'positive', 'negative', 'neutral'],
      },
      note_clean: {
        type: 'string',
        description: 'Cleaned, concise version of the original note',
      },
      duration_minutes: {
        type: 'number',
        description: 'Estimated or stated duration in minutes, null if unknown',
      },
    },
  },
};

/**
 * @param {object} rawInput - { note, type?, initiatedBy?, feelingBefore?, feelingDuring?, feelingAfter? }
 * @returns {object} Structured interaction fields
 */
export async function runLoggerAgent(rawInput) {
  if (!process.env.OPENAI_API_KEY) {
    return {
      type: rawInput.type ?? 'text',
      initiated_by: rawInput.initiatedBy ?? 'unclear',
      energy_rating: 0,
      vibe_rating: 0,
      sentiment: 'neutral',
      note_clean: rawInput.note ?? '',
      duration_minutes: null,
    };
  }

  const prompt = buildPrompt(rawInput);

  const response = await client.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [
      {
        role: 'system',
        content:
          'You are parsing interaction data for a relationship tracking app. ' +
          'Extract structured fields from the user description. Be conservative — if unsure, use neutral values.',
      },
      { role: 'user', content: prompt },
    ],
    tools: [{ type: 'function', function: INTERACTION_SCHEMA }],
    tool_choice: { type: 'function', function: { name: 'structure_interaction' } },
    temperature: 0,
  });

  const toolCall = response.choices[0].message.tool_calls?.[0];
  if (!toolCall) throw new Error('Logger agent returned no structured output');

  return JSON.parse(toolCall.function.arguments);
}

function buildPrompt(input) {
  const lines = [`Raw note: "${input.note || '(no note)'}"`];
  if (input.type) lines.push(`Interaction type (user-selected): ${input.type}`);
  if (input.initiatedBy) lines.push(`Initiated by (user-selected): ${input.initiatedBy}`);
  if (input.feelingBefore) lines.push(`Feeling before: ${input.feelingBefore}`);
  if (input.feelingDuring) lines.push(`Feeling during: ${input.feelingDuring}`);
  if (input.feelingAfter) lines.push(`Feeling after: ${input.feelingAfter}`);
  return lines.join('\n');
}
