// const User = require('../models/User');
// const generateToken = require('../utils/generateToken');

// exports.register = async (req, res, next) => {
//   try {
//     const { name, email, password } = req.body;
//     if (!name || !email || !password) {
//       return res.status(400).json({ success: false, message: 'Please provide all fields' });
//     }

//     const userExists = await User.findOne({ email });
//     if (userExists) {
//       return res.status(400).json({ success: false, message: 'User already exists' });
//     }

//     const user = await User.create({ name, email, password });

//     res.status(201).json({
//       success: true,
//       token: generateToken(user._id),
//       user: { id: user._id, name: user.name, email: user.email },
//     });
//   } catch (error) {
//     next(error);
//   }
// };

// // backend/controllers/authController.js
// exports.login = async (req, res, next) => {
//   try {
//     const { email, password } = req.body;

//     // 1. Explicitly request the password with .select('+password')
//     const user = await User.findOne({ email: email.toLowerCase().trim() }).select('+password');

//     if (!user) {
//       return res.status(401).json({ success: false, message: 'Invalid credentials' });
//     }

//     // 2. Use comparePassword (matches your User.js method name)
//     const isMatch = await user.comparePassword(password);
//     if (!isMatch) {
//       return res.status(401).json({ success: false, message: 'Invalid credentials' });
//     }

//     res.json({
//       success: true,
//       token: generateToken(user._id),
//       user: {
//         id: user._id,
//         name: user.name,
//         email: user.email,
//         currency: user.currency,
//       },
//     });
//   } catch (error) {
//     next(error);
//   }
// };

// // exports.login = async (req, res, next) => {
// //   try {
// //     const { email, password } = req.body;
// //     const user = await User.findOne({ email });

// //     if (user && (await user.matchPassword(password))) {
// //       res.json({
// //         success: true,
// //         token: generateToken(user._id),
// //         user: { id: user._id, name: user.name, email: user.email },
// //       });
// //     } else {
// //       res.status(401).json({ success: false, message: 'Invalid email or password' });
// //     }
// //   } catch (error) {
// //     next(error);
// //   }
// // };

// exports.getMe = async (req, res) => {
//   res.json({ success: true, user: req.user });
// };

// backend/controllers/authController.js
const User = require('../models/User');
const bcrypt = require('bcryptjs');
const generateToken = require('../utils/generateToken');

exports.register = async (req, res, next) => {
  try {
    const { name, email, password } = req.body;
    if (!name || !email || !password) {
      return res.status(400).json({ success: false, message: 'Please provide all fields' });
    }

    const userExists = await User.findOne({ email: email.toLowerCase().trim() });
    if (userExists) {
      return res.status(400).json({ success: false, message: 'User already exists' });
    }

    const user = await User.create({
      name,
      email: email.toLowerCase().trim(),
      password,
      currency: 'INR',
    });

    res.status(201).json({
      success: true,
      token: generateToken(user._id),
      user: { id: user._id, name: user.name, email: user.email },
    });
  } catch (error) {
    next(error);
  }
};

exports.login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Please provide email and password' });
    }

    // 1. Explicitly select password since select: false is set in schema
    const user = await User.findOne({ email: email.toLowerCase().trim() }).select('+password');

    if (!user) {
      return res.status(401).json({ success: false, message: 'Invalid credentials' });
    }

    // 2. Direct bcrypt comparison - never fails due to schema method mismatches
    const isMatch = await bcrypt.compare(password, user.password);

    if (!isMatch) {
      return res.status(401).json({ success: false, message: 'Invalid credentials' });
    }

    res.status(200).json({
      success: true,
      token: generateToken(user._id),
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        currency: user.currency || 'INR',
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.getMe = async (req, res) => {
  res.status(200).json({ success: true, user: req.user });
};