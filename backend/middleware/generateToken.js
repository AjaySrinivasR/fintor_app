const jwt = require('jsonwebtoken');

/**
 * Signs a JWT containing the user's id.
 * Kept as a standalone util so both authController and any
 * future "refresh" logic can reuse the same signing config.
 */
const generateToken = (userId) => {
  jwt.sign({ id: userId }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  });
};

module.exports = generateToken;
