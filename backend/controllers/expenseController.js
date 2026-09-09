const Expense = require('../models/Expense');
const Category = require('../models/Category');

// Fallback keyword classifier if category ID does not resolve
const fallbackCategoryFromTitle = (title = '') => {
  const t = title.toLowerCase();
  if (t.includes('biriyani') || t.includes('cafe') || t.includes('zomato') || t.includes('swiggy') || t.includes('food') || t.includes('restaurant')) {
    return 'Dining Out';
  }
  if (t.includes('oil') || t.includes('petrol') || t.includes('fuel') || t.includes('uber') || t.includes('ola')) {
    return 'Transportation';
  }
  if (t.includes('market') || t.includes('mart') || t.includes('grocery') || t.includes('store')) {
    return 'Groceries';
  }
  if (t.includes('bescom') || t.includes('airtel') || t.includes('jio') || t.includes('bill')) {
    return 'Utilities';
  }
  return 'General';
};

// 1. Fetch all expenses with category name resolution
exports.getExpenses = async (req, res, next) => {
  try {
    const rawExpenses = await Expense.find({ user: req.user._id })
      .lean()
      .sort({ date: -1 });

    const allCategories = await Category.find({}).lean();
    const categoryMap = {};
    allCategories.forEach((cat) => {
      categoryMap[cat._id.toString()] = cat.name;
    });

    const isHexObjectId = (str) => /^[0-9a-fA-F]{24}$/.test(str);

    const formatted = rawExpenses.map((e) => {
      const resolvedTitle = e.title || e.merchant || e.description || 'General Expense';

      let rawCat = e.category;
      if (rawCat && typeof rawCat === 'object' && rawCat._id) {
        rawCat = rawCat._id.toString();
      } else if (rawCat) {
        rawCat = rawCat.toString();
      }

      let resolvedCategory = categoryMap[rawCat];
      if (!resolvedCategory || isHexObjectId(resolvedCategory)) {
        resolvedCategory = fallbackCategoryFromTitle(resolvedTitle);
      }

      return {
        id: e._id.toString(),
        title: resolvedTitle,
        amount: e.amount,
        category: resolvedCategory,
        type: e.type || 'debit',
        source: e.source || 'manual',
        accountLast4: e.accountLast4 || null,
        date: e.date,
      };
    });

    res.status(200).json({ success: true, count: formatted.length, data: formatted });
  } catch (error) {
    next(error);
  }
};

// 2. Add single expense manually
exports.addExpense = async (req, res, next) => {
  try {
    const { title, amount, category, type, source, accountLast4, date } = req.body;
    const timestamp = date ? new Date(date).getTime() : Date.now();
    const syncHash = `${accountLast4 || 'NA'}_${amount}_${timestamp}_${type || 'debit'}`;

    const expense = await Expense.create({
      user: req.user._id,
      title,
      amount,
      category: category || 'General',
      type: type || 'debit',
      source: source || 'manual',
      accountLast4,
      syncHash,
      date: date || new Date(),
    });

    res.status(201).json({ success: true, data: expense });
  } catch (error) {
    next(error);
  }
};

// 3. Batch sync expenses from SMS / CSV
exports.syncBatchExpenses = async (req, res, next) => {
  try {
    const { expenses } = req.body;
    if (!Array.isArray(expenses) || expenses.length === 0) {
      return res.status(400).json({ success: false, message: 'No expenses provided' });
    }

    const bulkOps = expenses.map((item) => {
      const dateTimestamp = new Date(item.date).getTime();
      const syncHash =
        item.syncHash ||
        `${item.accountLast4 || 'NA'}_${item.amount}_${dateTimestamp}_${item.type || 'debit'}`;

      return {
        updateOne: {
          filter: { user: req.user._id, syncHash },
          update: {
            $setOnInsert: {
              user: req.user._id,
              title: item.title,
              amount: item.amount,
              category: item.category || 'General',
              type: item.type || 'debit',
              source: item.source || 'sms',
              accountLast4: item.accountLast4 || null,
              syncHash,
              date: item.date ? new Date(item.date) : new Date(),
            },
          },
          upsert: true,
        },
      };
    });

    const result = await Expense.bulkWrite(bulkOps, { ordered: false });

    res.status(200).json({
      success: true,
      message: 'Batch synchronization completed',
      inserted: result.upsertedCount,
      matched: result.matchedCount,
    });
  } catch (error) {
    next(error);
  }
};

// 4. Delete an expense
exports.deleteExpense = async (req, res, next) => {
  try {
    const expense = await Expense.findOneAndDelete({ _id: req.params.id, user: req.user._id });
    if (!expense) {
      return res.status(404).json({ success: false, message: 'Expense record not found' });
    }
    res.json({ success: true, message: 'Expense deleted' });
  } catch (error) {
    next(error);
  }
};

exports.updateExpense = async (req, res, next) => {
  try {
    const { title, amount, category, type, date } = req.body;

    const expense = await Expense.findOneAndUpdate(
      { _id: req.params.id, user: req.user._id },
      {
        title,
        amount: Number(amount),
        category,
        type: type || 'debit',
        date: date ? new Date(date) : undefined
      },
      { new: true, runValidators: true }
    );

    if (!expense) {
      return res.status(404).json({ success: false, message: 'Expense record not found' });
    }

    res.status(200).json({ success: true, data: expense });
  } catch (error) {
    next(error);
  }
};