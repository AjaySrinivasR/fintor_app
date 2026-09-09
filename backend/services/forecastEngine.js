import Expense from '../models/Expense.js';
import Budget from '../models/Budget.js';
import Category from '../models/Category.js';
import { linearRegression, weightedAverage } from './mathUtils.js';

const MIN_MONTHS_FOR_REGRESSION = 3;
const MIN_DAYS_FOR_ROLLING_TREND = 7; // fewer days than this -> simple run-rate instead
const DEFAULT_TREND_WINDOW_DAYS = 14;

// ---------- month math (self-contained on purpose — see note at bottom) ----------

const toMonthString = (date) => `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;

const shiftMonthString = (month, delta) => {
  const [year, mon] = month.split('-').map(Number);
  const d = new Date(year, mon - 1 + delta, 1);
  return toMonthString(d);
};

const monthDateRange = (month) => {
  const [year, mon] = month.split('-').map(Number);
  return { start: new Date(year, mon - 1, 1), end: new Date(year, mon, 1) };
};

const daysElapsedInMonth = (month, asOf) => {
  const [year, mon] = month.split('-').map(Number);
  const isCurrentMonth = asOf.getFullYear() === year && asOf.getMonth() === mon - 1;
  if (!isCurrentMonth) return null; // only meaningful for the in-progress month
  return asOf.getDate();
};

const daysInMonth = (month) => {
  const [year, mon] = month.split('-').map(Number);
  return new Date(year, mon, 0).getDate();
};

// ---------- data access ----------

/** Total spend for one month, optionally scoped to one category. */
const totalSpendForMonth = async (userId, month, categoryId) => {
  const { start, end } = monthDateRange(month);
  const match = { user: userId, date: { $gte: start, $lt: end } };
  if (categoryId) match.category = categoryId;

  const rows = await Expense.aggregate([
    { $match: match },
    { $group: { _id: null, total: { $sum: '$amount' } } },
  ]);
  return rows[0]?.total || 0;
};

// ---------- trend forecast (monthly, long-horizon) ----------

/**
 * Forecasts total spend for the month(s) following the last *complete*
 * calendar month. The current, still-in-progress month is deliberately
 * excluded from the historical series — its partial total isn't
 * comparable to full months and would bias the trend line downward.
 *
 * @param {ObjectId} userId
 * @param {ObjectId|null} categoryId - null forecasts overall spend across all categories
 * @param {object} options
 * @param {number} options.monthsBack - how many complete months of history to use (default 6)
 * @param {number} options.monthsAhead - how many months forward to project (default 1)
 * @param {Date} options.asOf - override "today" for testing/demo purposes
 */
const forecastTrend = async (userId, categoryId = null, options = {}) => {
  const { monthsBack = 6, monthsAhead = 1, asOf = new Date() } = options;

  const currentMonth = toMonthString(asOf);
  // Last complete month is the one immediately before the current (possibly partial) month
  const lastCompleteMonth = shiftMonthString(currentMonth, -1);

  // Build the list of complete months, oldest first
  const months = [];
  for (let i = monthsBack - 1; i >= 0; i--) {
    months.push(shiftMonthString(lastCompleteMonth, -i));
  }

  const historical = [];
  for (const month of months) {
    const total = await totalSpendForMonth(userId, month, categoryId);
    historical.push({ month, total });
  }

  const nonZeroCount = historical.filter((h) => h.total > 0).length;

  let method;
  let predictFn;

  if (nonZeroCount < MIN_MONTHS_FOR_REGRESSION) {
    // Not enough real history for a trend line to mean anything —
    // fall back to a recency-weighted average instead of extrapolating a slope
    method = nonZeroCount === 0 ? 'insufficient_data' : 'weighted_average';
    const avg = weightedAverage(historical.map((h) => h.total));
    predictFn = () => avg;
  } else {
    method = 'regression';
    const points = historical.map((h, i) => ({ x: i, y: h.total }));
    const { predict } = linearRegression(points);
    predictFn = (x) => Math.max(0, Math.round(predict(x))); // spend can't be negative
  }

  const forecast = [];
  for (let i = 1; i <= monthsAhead; i++) {
    const targetMonth = shiftMonthString(lastCompleteMonth, i);
    const x = historical.length - 1 + i;
    forecast.push({ month: targetMonth, predicted: Math.round(predictFn(x)) });
  }

  // Bonus: if the first forecasted month is the one currently in progress,
  // also surface actual spend so far so the UI can show "predicted vs actual pace"
  let actualSoFar = null;
  if (forecast.length > 0 && forecast[0].month === currentMonth) {
    const spent = await totalSpendForMonth(userId, currentMonth, categoryId);
    actualSoFar = {
      month: currentMonth,
      spent,
      daysElapsed: daysElapsedInMonth(currentMonth, asOf),
      daysInMonth: daysInMonth(currentMonth),
    };
  }

  let categoryInfo = null;
  if (categoryId) {
    const cat = await Category.findById(categoryId).select('name color');
    categoryInfo = cat ? { _id: cat._id, name: cat.name, color: cat.color } : null;
  }

  return { category: categoryInfo, method, historical, forecast, actualSoFar };
};

// ---------- month-end pace forecast (daily, short-horizon, "Azure-style") ----------

/**
 * Daily spend totals for a month, from day 1 through the given day
 * (inclusive). Days with no transactions are filled with 0 so the
 * cumulative series has no gaps.
 */
const dailySpendForMonth = async (userId, month, categoryId, throughDay) => {
  const { start } = monthDateRange(month);
  const end = new Date(start.getFullYear(), start.getMonth(), throughDay + 1);
  const match = { user: userId, date: { $gte: start, $lt: end } };
  if (categoryId) match.category = categoryId;

  const rows = await Expense.aggregate([
    { $match: match },
    { $group: { _id: { $dayOfMonth: '$date' }, total: { $sum: '$amount' } } },
  ]);
  const totalsByDay = Object.fromEntries(rows.map((r) => [r._id, r.total]));

  const daily = [];
  for (let day = 1; day <= throughDay; day++) {
    daily.push(totalsByDay[day] || 0);
  }
  return daily;
};

/**
 * PURE — Model 1 (Simple Run-Rate). Used for the first ~6 days of the
 * month, before a rolling window has enough points to be stable.
 * Just projects the average daily pace so far across the whole month.
 */
const computeSimpleRunRate = (cumulativeSoFar, daysElapsed, totalDaysInMonth) => {
  if (daysElapsed === 0) return 0;
  const dailyAvg = cumulativeSoFar / daysElapsed;
  return Math.round(dailyAvg * totalDaysInMonth);
};

/**
 * PURE — Model 2 (Recent-Window Trend). Fits a regression line through
 * only the last `window` days of the cumulative series and extrapolates
 * it to month-end. This is what actually reacts to a recent change in
 * spending pace, unlike the whole-month average in Model 1.
 *
 * @param {Array<{x: number, y: number}>} windowPoints - (day, cumulativeSpend) pairs
 * @param {number} totalDaysInMonth
 * @param {number} cumulativeSoFar - used as a floor; spend can't go backwards
 */
const computeRollingTrendForecast = (windowPoints, totalDaysInMonth, cumulativeSoFar) => {
  const { predict } = linearRegression(windowPoints);
  const raw = predict(totalDaysInMonth);
  return Math.round(Math.max(raw, cumulativeSoFar)); // never forecast less than what's already spent
};

/**
 * Forecasts this month's end-of-month total from the days elapsed so
 * far, the way Azure Cost Management projects current-period spend.
 *
 * @param {ObjectId} userId
 * @param {ObjectId|null} categoryId - null forecasts overall spend
 * @param {object} options
 * @param {number} options.windowDays - rolling window size for Model 2 (default 14)
 * @param {Date} options.asOf - override "today" for testing/demo purposes
 */
const forecastMonthEnd = async (userId, categoryId = null, options = {}) => {
  const { windowDays = DEFAULT_TREND_WINDOW_DAYS, asOf = new Date() } = options;

  const month = toMonthString(asOf);
  const totalDaysInMonth = daysInMonth(month);
  const daysElapsed = Math.min(asOf.getDate(), totalDaysInMonth);

  const dailyTotals = await dailySpendForMonth(userId, month, categoryId, daysElapsed);

  // Build the cumulative series: [{day: 1, cumulative: X}, {day: 2, cumulative: X+Y}, ...]
  let running = 0;
  const cumulativeSeries = dailyTotals.map((amount, i) => {
    running += amount;
    return { day: i + 1, cumulative: running };
  });
  const cumulativeSoFar = running;

  let method;
  let forecastEndOfMonth;

  if (daysElapsed < MIN_DAYS_FOR_ROLLING_TREND) {
    method = 'simple_run_rate';
    forecastEndOfMonth = computeSimpleRunRate(cumulativeSoFar, daysElapsed, totalDaysInMonth);
  } else {
    method = 'rolling_trend';
    const window = cumulativeSeries.slice(-windowDays);
    const points = window.map((p) => ({ x: p.day, y: p.cumulative }));
    forecastEndOfMonth = computeRollingTrendForecast(points, totalDaysInMonth, cumulativeSoFar);
  }

  let budgetLimit = null;
  if (categoryId) {
    const budget = await Budget.findOne({ user: userId, category: categoryId, month });
    budgetLimit = budget?.limitAmount ?? null;
  }

  let categoryInfo = null;
  if (categoryId) {
    const cat = await Category.findById(categoryId).select('name color');
    categoryInfo = cat ? { _id: cat._id, name: cat.name, color: cat.color } : null;
  }

  return {
    category: categoryInfo,
    month,
    daysElapsed,
    totalDaysInMonth,
    cumulativeSoFar,
    method,
    forecastEndOfMonth,
    budgetLimit,
    projectedToExceedBudget: budgetLimit !== null ? forecastEndOfMonth > budgetLimit : null,
    dailySeries: cumulativeSeries,
  };
};

export {
  forecastTrend,
  forecastMonthEnd,
  computeSimpleRunRate,
  computeRollingTrendForecast,
};

/**
 * Note on the duplicated month-math helpers above: ruleEngine.js has
 * its own near-identical prevMonth/monthDateRange helpers. That's a
 * deliberate choice, not an oversight — keeping each service
 * self-contained means changing one can't silently break the other,
 * which matters more than a few lines of DRY-ness at this scope. If
 * this project grows past a student prototype, promoting these into
 * a shared utils/monthMath.js would be the natural next refactor.
 */
