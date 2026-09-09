const express = require('express');
const router = express.Router();
const { importCsv } = require('../controllers/importController');
const { protect } = require('../middleware/auth');
const { uploadCsv } = require('../middleware/upload');

router.use(protect);

router.post('/csv', uploadCsv.single('file'), importCsv);

module.exports = router;
