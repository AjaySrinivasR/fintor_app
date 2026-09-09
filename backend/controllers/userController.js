const User = require('../models/User');

// @desc    Get user financial profile
// @route   GET /api/user/profile
// @access  Private
exports.getUserProfile = async (req, res, next) => {
    try {
        const user = await User.findById(req.user._id).select('name email monthlyIncome liquidReserves riskProfile monthlyBudget');
        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }
        res.status(200).json({ success: true, data: user });
    } catch (error) {
        next(error);
    }
};

// @desc    Update income, reserves and risk parameters
// @route   PUT /api/user/profile
// @access  Private
exports.updateUserProfile = async (req, res, next) => {
    try {
        const { monthlyIncome, liquidReserves, riskProfile, monthlyBudget } = req.body;

        const user = await User.findByIdAndUpdate(
            req.user._id,
            {
                monthlyIncome: monthlyIncome !== undefined ? Number(monthlyIncome) : undefined,
                liquidReserves: liquidReserves !== undefined ? Number(liquidReserves) : undefined,
                monthlyBudget: monthlyBudget !== undefined ? Number(monthlyBudget) : undefined,
                riskProfile,
            },
            { new: true, runValidators: true }
        ).select('-password');

        res.status(200).json({ success: true, data: user });
    } catch (error) {
        next(error);
    }
};