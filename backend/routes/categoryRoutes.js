const express = require('express');
const router = express.Router();
const { getCategories, addCategory } = require('../controllers/categoryController');
const { protect } = require('../middleware/auth');

router.use(protect);
router.route('/').get(getCategories).post(addCategory);

module.exports = router;