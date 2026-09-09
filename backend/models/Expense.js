const mongoose = require('mongoose');

const expenseSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    title: {
      type: String,
      required: true,
      trim: true,
    },
    amount: {
      type: Number,
      required: true,
    },
    category: {
      type: String,
      required: true,
      default: 'General',
      index: true,
    },
    type: {
      type: String,
      enum: ['debit', 'credit'],
      default: 'debit',
    },
    source: {
      type: String,
      enum: ['manual', 'sms', 'csv'],
      default: 'manual',
    },
    accountLast4: {
      type: String,
      trim: true,
    },
    syncHash: {
      type: String,
      index: true,
    },
    date: {
      type: Date,
      default: Date.now,
      index: true,
    },
  },
  { timestamps: true }
);

// Compound index guarantees idempotency for SMS ingestion
expenseSchema.index({ user: 1, syncHash: 1 }, { unique: true, sparse: true });

module.exports = mongoose.model('Expense', expenseSchema);