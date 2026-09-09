const mongoose = require('mongoose');

const plannerTipSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    // Which rule in the engine produced this tip — lets the frontend
    // pick an icon/color and lets us avoid duplicate tips
    type: {
      type: String,
      enum: ['category_spike', 'subscription_leak', 'budget_milestone'],
      required: true,
    },
    severity: {
      type: String,
      enum: ['info', 'warning', 'success'],
      default: 'info',
    },
    message: {
      type: String,
      required: true,
    },
    // Optional link back to the category this tip is about
    relatedCategory: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Category',
      default: null,
    },
    // "YYYY-MM" — the month this insight was generated for
    month: {
      type: String,
      required: true,
      match: [/^\d{4}-\d{2}$/, 'month must be in YYYY-MM format'],
    },
    isRead: {
      type: Boolean,
      default: false,
    },
  },
  { timestamps: true }
);

plannerTipSchema.index({ user: 1, month: 1 });

module.exports = mongoose.model('PlannerTip', plannerTipSchema);
