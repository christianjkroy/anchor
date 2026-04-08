/**
 * HTTP client for the R Plumber API (runs at R_PLUMBER_URL).
 */

const R_BASE = process.env.R_PLUMBER_URL || 'http://localhost:8000';

export async function callRAnalysis(endpoint, body) {
  const url = R_BASE + endpoint;
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(10_000),
  });
  if (!response.ok) {
    throw new Error(`R API ${endpoint} returned ${response.status}`);
  }
  return response.json();
}
