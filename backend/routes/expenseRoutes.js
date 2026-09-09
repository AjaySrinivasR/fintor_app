// backend/routes/expenseRoutes.js
const express = require('express');
const router = express.Router();
const {
    getExpenses,
    addExpense,
    syncBatchExpenses,
    updateExpense,
    deleteExpense,
} = require('../controllers/expenseController');
const { protect } = require('../middleware/auth');

router.use(protect);

router.route('/')
    .get(getExpenses)
    .post(addExpense);

router.post('/sync-batch', syncBatchExpenses);

router.route('/:id')
    .put(updateExpense)
    .delete(deleteExpense);

module.exports = router;