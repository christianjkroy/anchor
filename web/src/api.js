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

function buildQuery(params = {}) {
  const q = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== null) q.set(k, String(v));
  }
  const s = q.toString();
  return s ? `?${s}` : '';
}

export const api = {
  auth: {
    register: (payload) => request('/auth/register', { method: 'POST', body: JSON.stringify(payload) }),
    login:    (payload) => request('/auth/login',    { method: 'POST', body: JSON.stringify(payload) }),
    me:       ()        => request('/auth/me'),
  },

  persons: {
    list:    ()         => request('/persons'),
    create:  (payload)  => request('/persons', { method: 'POST', body: JSON.stringify(payload) }),
    stats:   (id)       => request(`/persons/${id}/stats`),
    network: ()         => request('/persons/graph/network'),
  },

  interactions: {
    list:   (params = {}) => request(`/interactions${buildQuery(params)}`),
    create: (payload)     => request('/interactions', { method: 'POST', body: JSON.stringify(payload) }),
  },

  insights: {
    list: () => request('/insights'),
  },

  perception: {
    list:   ()                        => request('/perception'),
    submit: (personId, perceivedScore) =>
      request('/perception', { method: 'POST', body: JSON.stringify({ personId, perceivedScore }) }),
  },

  digest: {
    list:     ()        => request('/digest'),
    generate: (payload) => request('/digest/generate', { method: 'POST', body: JSON.stringify(payload) }),
  },
};
