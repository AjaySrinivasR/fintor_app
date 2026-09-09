const Category = require('../models/Category');

exports.getCategories = async (req, res, next) => {
  try {
    const categories = await Category.find({ user: req.user._id });
    res.json({ success: true, data: categories });
  } catch (error) {
    next(error);
  }
};

exports.addCategory = async (req, res, next) => {
  try {
    const { name, iconCode, colorValue, keywords } = req.body;
    const category = await Category.create({
      user: req.user._id,
      name,
      iconCode,
      colorValue,
      keywords: keywords || [],
    });
    res.status(201).json({ success: true, data: category });
  } catch (error) {
    next(error);
  }
};