const Expense = require('../models/Expense');
const Budget = require('../models/Budget');
const { generateInsights } = require('../services/ruleEngine');

exports.getInsights = async (req, res, next) => {
  try {
    const expenses = await Expense.find({ user: req.user._id });
    const budgets = await Budget.find({ user: req.user._id });
    const insights = generateInsights(expenses, budgets);
    res.json({ success: true, data: insights });
  } catch (error) {
    next(error);
  }
};