const mongoose = require('mongoose');

const categorySchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    iconCode: {
      type: Number,
      default: 58133,
    },
    colorValue: {
      type: Number,
      default: 0xFF1E3A8A,
    },
    keywords: [
      {
        type: String,
        lowercase: true,
        trim: true,
      },
    ],
  },
  { timestamps: true }
);

module.exports = mongoose.model('Category', categorySchema);