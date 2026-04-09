import OpenAI from 'openai';
import { getCompatibleOpenAIConfig, getServiceConfig } from './service_config.js';

const EMBEDDING_DIMENSIONS = 384;

const clientConfig = getCompatibleOpenAIConfig();
const client = clientConfig
  ? new OpenAI(clientConfig)
  : null;

export function getEmbeddingDimensions() {
  return EMBEDDING_DIMENSIONS;
}

export async function createInteractionEmbedding(input) {
  const text = normalizeEmbeddingInput(input);
  if (!text) return null;

  if (client) {
    const serviceConfig = getServiceConfig();
    const request = {
      model: serviceConfig.llm.embeddingModel,
      input: text,
    };

    if (serviceConfig.llm.provider !== 'ollama') {
      request.dimensions = EMBEDDING_DIMENSIONS;
    }

    const response = await client.embeddings.create(request);
    return response.data[0]?.embedding ?? null;
  }

  return createDeterministicEmbedding(text, EMBEDDING_DIMENSIONS);
}

export function embeddingToSqlVector(embedding) {
  if (!Array.isArray(embedding) || !embedding.length) return null;
  return `[${embedding.join(',')}]`;
}

function normalizeEmbeddingInput(input) {
  if (!input) return '';

  if (typeof input === 'string') {
    return input.trim();
  }

  if (typeof input === 'object') {
    const parts = [
      input.note,
      input.feelingBefore ? `Before: ${input.feelingBefore}` : '',
      input.feelingDuring ? `During: ${input.feelingDuring}` : '',
      input.feelingAfter ? `After: ${input.feelingAfter}` : '',
      input.type ? `Type: ${input.type}` : '',
      input.initiatedBy ? `Initiated by: ${input.initiatedBy}` : '',
      input.sentiment ? `Sentiment: ${input.sentiment}` : '',
    ].filter(Boolean);
    return parts.join('\n').trim();
  }

  return '';
}

function createDeterministicEmbedding(text, dimensions) {
  const vector = new Array(dimensions).fill(0);
  const normalized = text.toLowerCase();

  for (const token of normalized.split(/\W+/).filter(Boolean)) {
    let hash = 2166136261;
    for (let i = 0; i < token.length; i += 1) {
      hash ^= token.charCodeAt(i);
      hash = Math.imul(hash, 16777619);
    }

    const index = Math.abs(hash) % dimensions;
    const sign = hash & 1 ? 1 : -1;
    vector[index] += sign;
  }

  const magnitude = Math.sqrt(vector.reduce((sum, value) => sum + value * value, 0));
  if (!magnitude) return vector;

  return vector.map((value) => Number((value / magnitude).toFixed(6)));
}
