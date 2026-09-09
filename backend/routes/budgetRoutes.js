const express = require('express');
const router = express.Router();
const { getBudgets, setBudget } = require('../controllers/budgetController');
const { protect } = require('../middleware/auth');

router.use(protect);
router.route('/').get(getBudgets).post(setBudget);

module.exports = router;