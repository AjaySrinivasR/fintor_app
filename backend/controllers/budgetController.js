const Budget = require('../models/Budget');

exports.getBudgets = async (req, res, next) => {
  try {
    const budgets = await Budget.find({ user: req.user._id });
    res.json({ success: true, data: budgets });
  } catch (error) {
    next(error);
  }
};

exports.setBudget = async (req, res, next) => {
  try {
    const { category, limitAmount, monthYear } = req.body;
    const budget = await Budget.findOneAndUpdate(
      { user: req.user._id, category, monthYear },
      { limitAmount },
      { new: true, upsert: true }
    );
    res.json({ success: true, data: budget });
  } catch (error) {
    next(error);
  }
};