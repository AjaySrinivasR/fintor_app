const fs = require('fs');
const csvParser = require('csv-parser');
const Expense = require('../models/Expense');
const Category = require('../models/Category');
const { guessCategory } = require('../middleware/categorizer');

/**
 * Expected CSV columns (case-insensitive header match):
 *   date, merchant, amount, category (category is optional)
 *
 * Example row:
 *   2026-08-14, Swiggy, 450, Dining Out
 */

// @route  POST /api/import/csv   (multipart/form-data, field name: "file")
// @access Private
exports.importCsv = async (req, res, next) => {
  if (!req.file) {
    return res.status(400).json({ message: 'No CSV file uploaded (field name must be "file")' });
  }

  try {
    const userCategories = await Category.find({ user: req.user._id });
    const categoryByName = Object.fromEntries(
      userCategories.map((c) => [c.name.toLowerCase(), c.name])
    );

    const rows = await parseCsvFile(req.file.path);

    const toInsert = [];
    const errors = [];

    rows.forEach((row, index) => {
      const rowNum = index + 2; // +1 for 0-index, +1 for header row
      const normalized = normalizeRow(row);

      if (!normalized.merchant || !normalized.amount || !normalized.date) {
        errors.push({ row: rowNum, reason: 'Missing merchant, amount, or date' });
        return;
      }

      const amount = parseFloat(normalized.amount);
      if (Number.isNaN(amount) || amount <= 0) {
        errors.push({ row: rowNum, reason: `Invalid amount "${normalized.amount}"` });
        return;
      }

      const date = new Date(normalized.date);
      if (Number.isNaN(date.getTime())) {
        errors.push({ row: rowNum, reason: `Invalid date "${normalized.date}"` });
        return;
      }

      // Resolution order: explicit category column -> keyword guess -> fallback to 'General'
      let categoryName = null;
      if (normalized.category) {
        categoryName = categoryByName[normalized.category.toLowerCase()] || normalized.category;
      }

      if (!categoryName) {
        const matchedId = guessCategory(normalized.merchant, userCategories);
        if (matchedId) {
          const matched = userCategories.find((c) => c._id.toString() === matchedId.toString());
          if (matched) categoryName = matched.name;
        }
      }

      if (!categoryName) {
        categoryName = 'General';
      }

      toInsert.push({
        user: req.user._id,
        title: normalized.merchant,
        amount,
        category: categoryName,
        type: 'debit',
        source: 'csv',
        date,
      });
    });

    let inserted = [];
    if (toInsert.length > 0) {
      inserted = await Expense.insertMany(toInsert);
    }

    // Clean up the uploaded file — we don't need to keep the raw CSV around
    fs.unlink(req.file.path, () => {});

    res.status(201).json({
      totalRows: rows.length,
      imported: inserted.length,
      skipped: errors.length,
      errors,
    });
  } catch (err) {
    if (req.file && req.file.path) {
      fs.unlink(req.file.path, () => {});
    }
    next(err);
  }
};

// Reads the CSV off disk and resolves with an array of row objects
const parseCsvFile = (filePath) => {
  return new Promise((resolve, reject) => {
    const rows = [];
    fs.createReadStream(filePath)
      .pipe(csvParser({ mapHeaders: ({ header }) => header.trim().toLowerCase() }))
      .on('data', (row) => rows.push(row))
      .on('end', () => resolve(rows))
      .on('error', reject);
  });
};

// Trims whitespace and tolerates a couple of common header name variants
const normalizeRow = (row) => ({
  date: (row.date || row.transaction_date || '').trim(),
  merchant: (row.merchant || row.description || row.narration || '').trim(),
  amount: (row.amount || row.debit || row.withdrawal || '').trim(),
  category: (row.category || '').trim(),
});
