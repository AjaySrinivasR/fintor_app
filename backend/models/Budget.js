const mongoose = require('mongoose');

const budgetSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    category: {
      type: String,
      required: true,
    },
    limitAmount: {
      type: Number,
      required: true,
    },
    monthYear: {
      type: String, // 'YYYY-MM'
      required: true,
    },
  },
  { timestamps: true }
);

budgetSchema.index({ user: 1, category: 1, monthYear: 1 }, { unique: true });

module.exports = mongoose.model('Budget', budgetSchema);