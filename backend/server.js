const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const connectDB = require('./config/db');
const errorHandler = require('./middleware/errorHandler');

// Load environment variables
dotenv.config();

// Connect to MongoDB
connectDB();

const app = express();

// Global Middlewares
app.use(cors());
app.use(express.json());

// Mount API Routes
app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api/expenses', require('./routes/expenseRoutes'));
app.use('/api/budgets', require('./routes/budgetRoutes'));
app.use('/api/categories', require('./routes/categoryRoutes'));
app.use('/api/insights', require('./routes/insightRoutes'));
app.use('/api/sms', require('./routes/smsRoutes'));
app.use('/api/user', require('./routes/userRoutes'));

// Health Check
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', timestamp: new Date() });
});

// Centralized Error Handling
app.use(errorHandler);

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Fintor backend running on port ${PORT}`);
});
