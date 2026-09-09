const express = require('express');
const router = express.Router();
const { getUserProfile, updateUserProfile } = require('../controllers/userController');
const { protect } = require('../middleware/auth');

router.use(protect);

router.route('/profile')
    .get(getUserProfile)
    .put(updateUserProfile);

module.exports = router;