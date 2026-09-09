/**
 * Pure statistical helpers — no DB, no Express, nothing async. Kept
 * separate from forecastEngine.js so the math itself is trivially
 * unit-testable and reusable by both the trend forecaster (monthly)
 * and, later, the month-end pace forecaster (daily).
 */

/**
 * Ordinary least-squares linear regression on a set of {x, y} points.
 * Returns the fitted line as slope + intercept, plus a predict(x) helper.
 *
 * @param {Array<{x: number, y: number}>} points
 * @returns {{ slope: number, intercept: number, predict: (x:number) => number }}
 */
const linearRegression = (points) => {
  const n = points.length;
  if (n < 2) {
    throw new Error('linearRegression needs at least 2 points');
  }

  const sumX = points.reduce((s, p) => s + p.x, 0);
  const sumY = points.reduce((s, p) => s + p.y, 0);
  const sumXY = points.reduce((s, p) => s + p.x * p.y, 0);
  const sumXX = points.reduce((s, p) => s + p.x * p.x, 0);

  const denominator = n * sumXX - sumX * sumX;
  // All x values identical (shouldn't happen with sequential month/day
  // indices, but guard against divide-by-zero anyway)
  const slope = denominator === 0 ? 0 : (n * sumXY - sumX * sumY) / denominator;
  const intercept = (sumY - slope * sumX) / n;

  return {
    slope,
    intercept,
    predict: (x) => slope * x + intercept,
  };
};

/**
 * Weighted average, most-recent-first. Used as the fallback forecast
 * when there isn't enough history for a regression line to be
 * meaningful (fewer than 3 data points).
 *
 * @param {number[]} values - values in chronological order (oldest first)
 * @param {number[]} weights - same length as values, or omitted for
 *   a sensible default that favors recency (e.g. [1,2,3] for 3 values)
 */
const weightedAverage = (values, weights = null) => {
  if (values.length === 0) return 0;
  const w = weights || values.map((_, i) => i + 1); // 1,2,3... so latest counts most
  const weightedSum = values.reduce((s, v, i) => s + v * w[i], 0);
  const totalWeight = w.reduce((s, x) => s + x, 0);
  return totalWeight === 0 ? 0 : weightedSum / totalWeight;
};

module.exports = { linearRegression, weightedAverage };
