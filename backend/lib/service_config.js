function readEnv(name) {
  const value = process.env[name];
  if (typeof value !== 'string') return '';
  return value.trim();
}

export function getServiceConfig() {
  const llmProvider = normalizeProvider(readEnv('LLM_PROVIDER') || 'openai');
  const openAIKey = readEnv('OPENAI_API_KEY');
  const rPlumberUrl = readEnv('R_PLUMBER_URL');
  const ollamaBaseUrl = stripTrailingSlash(readEnv('OLLAMA_BASE_URL') || 'http://localhost:11434');
  const chatModel = llmProvider === 'ollama'
    ? (readEnv('OLLAMA_CHAT_MODEL') || 'llama3.2')
    : (readEnv('OPENAI_CHAT_MODEL') || 'gpt-4o-mini');
  const embeddingModel = llmProvider === 'ollama'
    ? (readEnv('OLLAMA_EMBEDDING_MODEL') || 'all-minilm')
    : (readEnv('OPENAI_EMBEDDING_MODEL') || 'text-embedding-3-small');
  const llmEnabled = llmProvider === 'ollama' ? true : Boolean(openAIKey);

  return {
    llm: {
      enabled: llmEnabled,
      provider: llmEnabled ? llmProvider : 'fallback',
      mode: llmEnabled ? 'remote' : 'fallback',
      chatModel,
      embeddingModel,
      baseUrl: llmProvider === 'ollama' ? `${ollamaBaseUrl}/v1` : 'https://api.openai.com/v1',
    },
    openAI: {
      enabled: llmProvider === 'openai' && Boolean(openAIKey),
      mode: llmProvider === 'openai' && openAIKey ? 'remote' : 'fallback',
      chatModel: readEnv('OPENAI_CHAT_MODEL') || 'gpt-4o-mini',
      embeddingModel: readEnv('OPENAI_EMBEDDING_MODEL') || 'text-embedding-3-small',
    },
    ollama: {
      enabled: llmProvider === 'ollama',
      mode: llmProvider === 'ollama' ? 'remote' : 'fallback',
      chatModel: readEnv('OLLAMA_CHAT_MODEL') || 'llama3.2',
      embeddingModel: readEnv('OLLAMA_EMBEDDING_MODEL') || 'all-minilm',
      baseUrl: ollamaBaseUrl,
    },
    rPlumber: {
      enabled: Boolean(rPlumberUrl),
      mode: rPlumberUrl ? 'remote' : 'fallback',
      url: rPlumberUrl || null,
    },
  };
}

export function isLLMEnabled() {
  return getServiceConfig().llm.enabled;
}

export function isRPlumberEnabled() {
  return getServiceConfig().rPlumber.enabled;
}

export function getCompatibleOpenAIConfig() {
  const { llm } = getServiceConfig();
  if (!llm.enabled) return null;

  if (llm.provider === 'ollama') {
    return {
      apiKey: 'ollama',
      baseURL: llm.baseUrl,
    };
  }

  return {
    apiKey: readEnv('OPENAI_API_KEY'),
    baseURL: llm.baseUrl,
  };
}

function normalizeProvider(value) {
  const normalized = value.toLowerCase();
  return normalized === 'ollama' ? 'ollama' : 'openai';
}

function stripTrailingSlash(value) {
  return value.replace(/\/+$/, '');
}
