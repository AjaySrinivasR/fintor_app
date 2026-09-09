const { forecastTrend, forecastMonthEnd } = require('../services/forecastEngine');
const Category = require('../models/Category');

// @route  GET /api/forecast/trend?category=<id optional>&monthsBack=6&monthsAhead=1
// @access Private
exports.getTrendForecast = async (req, res, next) => {
  try {
    const { category, monthsBack, monthsAhead } = req.query;

    if (category) {
      const categoryDoc = await Category.findOne({ _id: category, user: req.user.id });
      if (!categoryDoc) return res.status(400).json({ message: 'Invalid category' });
    }

    const result = await forecastTrend(req.user.id, category || null, {
      monthsBack: monthsBack ? parseInt(monthsBack, 10) : undefined,
      monthsAhead: monthsAhead ? parseInt(monthsAhead, 10) : undefined,
    });

    res.json(result);
  } catch (err) {
    next(err);
  }
};

// @route  GET /api/forecast/month-end?category=<id optional>&windowDays=14
// @access Private
exports.getMonthEndForecast = async (req, res, next) => {
  try {
    const { category, windowDays } = req.query;

    if (category) {
      const categoryDoc = await Category.findOne({ _id: category, user: req.user._id });
      if (!categoryDoc) return res.status(400).json({ message: 'Invalid category' });
    }

    const result = await forecastMonthEnd(req.user._id, category || null, {
      windowDays: windowDays ? parseInt(windowDays, 10) : undefined,
    });

    res.json(result);
  } catch (err) {
    next(err);
  }
};
