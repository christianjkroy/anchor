export function computeInitiationRatio(interactions) {
  const meaningful = interactions.filter((i) => i.initiated_by === 'user' || i.initiated_by === 'them');
  if (!meaningful.length) return 0.5;
  const theyInitiated = meaningful.filter((i) => i.initiated_by === 'them').length;
  return theyInitiated / meaningful.length;
}

export function computeConsistencyScore(interactions) {
  if (interactions.length < 3) return 0.5;

  const sorted = [...interactions].sort((a, b) => new Date(a.created_at) - new Date(b.created_at));
  const gaps = [];

  for (let i = 1; i < sorted.length; i += 1) {
    gaps.push((new Date(sorted[i].created_at) - new Date(sorted[i - 1].created_at)) / 86400000);
  }

  if (!gaps.length) return 0.5;
  const mean = gaps.reduce((sum, value) => sum + value, 0) / gaps.length;
  const variance = gaps.reduce((sum, value) => sum + (value - mean) ** 2, 0) / gaps.length;
  const stdDev = Math.sqrt(variance);

  return clamp01(1 - stdDev / (mean + 1));
}

export function computeEnergyTrend(interactions, windowSize = 10) {
  const withEnergy = interactions
    .filter((i) => typeof i.energy_rating === 'number')
    .sort((a, b) => new Date(a.created_at) - new Date(b.created_at));

  if (withEnergy.length < 2) return 0;

  const recent = withEnergy.slice(-windowSize);
  const xs = recent.map((_, idx) => idx + 1);
  const ys = recent.map((i) => i.energy_rating);

  const xMean = xs.reduce((sum, x) => sum + x, 0) / xs.length;
  const yMean = ys.reduce((sum, y) => sum + y, 0) / ys.length;

  let numerator = 0;
  let denominator = 0;
  for (let i = 0; i < xs.length; i += 1) {
    numerator += (xs[i] - xMean) * (ys[i] - yMean);
    denominator += (xs[i] - xMean) ** 2;
  }

  if (denominator === 0) return 0;
  return numerator / denominator;
}

export function computeFollowThroughRate(interactions) {
  const outcomes = interactions.filter((i) => i.feeling_after);
  if (!outcomes.length) return 0.5;

  const positiveOutcomes = outcomes.filter((i) => {
    const value = String(i.feeling_after).toLowerCase();
    return ['better', 'good', 'connected', 'calm', 'seen', 'energized'].some((token) => value.includes(token));
  }).length;

  return positiveOutcomes / outcomes.length;
}

export function computeRealityScore({ initiationRatio, consistencyScore, energyTrend, followThroughRate }) {
  const normalizedTrend = clamp01((energyTrend + 0.2) / 0.4);
  const weighted =
    initiationRatio * 0.35 +
    consistencyScore * 0.25 +
    followThroughRate * 0.25 +
    normalizedTrend * 0.15;

  return clampToRange(1 + weighted * 4, 1, 5);
}

export function computeDivergence(perceivedScore, realityScore) {
  return Math.abs(perceivedScore - realityScore);
}

function clamp01(value) {
  return clampToRange(value, 0, 1);
}

function clampToRange(value, min, max) {
  return Math.max(min, Math.min(max, value));
}
