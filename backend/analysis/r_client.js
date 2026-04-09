/**
 * HTTP client for the R Plumber API (runs at R_PLUMBER_URL).
 */
import { getServiceConfig } from '../lib/service_config.js';

export async function callRAnalysis(endpoint, body) {
  const { rPlumber } = getServiceConfig();
  if (!rPlumber.enabled || !rPlumber.url) {
    const error = new Error('R Plumber service is not configured');
    error.code = 'R_NOT_CONFIGURED';
    throw error;
  }

  const url = rPlumber.url + endpoint;
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
