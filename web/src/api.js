const API_BASE = import.meta.env.VITE_API_BASE ?? '/api';

let token = localStorage.getItem('anchor_token') ?? '';

export function setToken(nextToken) {
  token = nextToken;
  if (token) localStorage.setItem('anchor_token', token);
  else localStorage.removeItem('anchor_token');
}

export function getToken() {
  return token;
}

async function request(path, options = {}) {
  const headers = {
    'Content-Type': 'application/json',
    ...(options.headers || {}),
  };

  if (token) headers.Authorization = `Bearer ${token}`;

  const response = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers,
  });

  if (!response.ok) {
    const body = await response.json().catch(() => ({}));
    throw new Error(body.error ?? `Request failed with status ${response.status}`);
  }

  if (response.status === 204) return null;
  return response.json();
}

export const api = {
  register: (payload) => request('/auth/register', { method: 'POST', body: JSON.stringify(payload) }),
  login: (payload) => request('/auth/login', { method: 'POST', body: JSON.stringify(payload) }),
  me: () => request('/auth/me'),
  persons: () => request('/persons'),
  createPerson: (payload) => request('/persons', { method: 'POST', body: JSON.stringify(payload) }),
  personStats: (personId) => request(`/persons/${personId}/stats`),
  network: () => request('/persons/graph/network'),
  interactions: (params = '') => request(`/interactions${params}`),
  createInteraction: (payload) => request('/interactions', { method: 'POST', body: JSON.stringify(payload) }),
  insights: () => request('/insights'),
  perceptionChecks: () => request('/perception'),
  createPerceptionCheck: (payload) => request('/perception', { method: 'POST', body: JSON.stringify(payload) }),
  digests: () => request('/digest'),
  generateDigest: (payload = {}) => request('/digest/generate', { method: 'POST', body: JSON.stringify(payload) }),
};
