const express = require('express');
const { getTrendForecast, getMonthEndForecast } = require('../controllers/forecastController.js');
const { protect } = require('../middleware/auth.js');

const router = express.Router();

router.use(protect);

router.get('/trend', getTrendForecast);
router.get('/month-end', getMonthEndForecast);

module.exports = router;
