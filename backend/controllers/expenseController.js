const Expense = require('../models/Expense');
const Category = require('../models/Category');

// Fallback keyword classifier if category ID does not resolve
const fallbackCategoryFromTitle = (title = '') => {
  const t = title.toLowerCase();
  if (
    t.includes('swiggy') ||
    t.includes('zomato') ||
    t.includes('blinkit') ||
    t.includes('zepto') ||
    t.includes('instamart') ||
    t.includes('mcdonald') ||
    t.includes('kfc') ||
    t.includes('dominos') ||
    t.includes('pizza') ||
    t.includes('burger') ||
    t.includes('biriyani') ||
    t.includes('biryani') ||
    t.includes('cafe') ||
    t.includes('coffee') ||
    t.includes('starbucks') ||
    t.includes('food') ||
    t.includes('restaurant') ||
    t.includes('dine')
  ) {
    return 'Food & Dining';
  }
  if (
    t.includes('uber') ||
    t.includes('ola') ||
    t.includes('rapido') ||
    t.includes('petrol') ||
    t.includes('fuel') ||
    t.includes('hpcl') ||
    t.includes('bpcl') ||
    t.includes('ioc') ||
    t.includes('shell') ||
    t.includes('oil') ||
    t.includes('metro') ||
    t.includes('irctc') ||
    t.includes('fastag') ||
    t.includes('flight')
  ) {
    return 'Travel & Fuel';
  }
  if (
    t.includes('netflix') ||
    t.includes('spotify') ||
    t.includes('hotstar') ||
    t.includes('prime') ||
    t.includes('pvr') ||
    t.includes('inox') ||
    t.includes('bookmyshow') ||
    t.includes('cinema') ||
    t.includes('movie') ||
    t.includes('youtube')
  ) {
    return 'Entertainment';
  }
  if (
    t.includes('airtel') ||
    t.includes('jio') ||
    t.includes('vi') ||
    t.includes('bescom') ||
    t.includes('electricity') ||
    t.includes('water') ||
    t.includes('gas') ||
    t.includes('bill') ||
    t.includes('recharge') ||
    t.includes('broadband') ||
    t.includes('tata play') ||
    t.includes('tata sky')
  ) {
    return 'Utilities & Bills';
  }
  if (
    t.includes('zerodha') ||
    t.includes('groww') ||
    t.includes('upstox') ||
    t.includes('mutual fund') ||
    t.includes('sip') ||
    t.includes('invest') ||
    t.includes('kuvera') ||
    t.includes('etmoney')
  ) {
    return 'Investments & SIP';
  }
  if (
    t.includes('amazon') ||
    t.includes('flipkart') ||
    t.includes('myntra') ||
    t.includes('ajio') ||
    t.includes('dmart') ||
    t.includes('bigbasket') ||
    t.includes('market') ||
    t.includes('mart') ||
    t.includes('grocery') ||
    t.includes('store') ||
    t.includes('retail') ||
    t.includes('mall')
  ) {
    return 'Shopping';
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