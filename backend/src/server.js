require('dotenv').config();
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const { initializeFirebase } = require('./config/firebase');

// Import routes
const authRoutes = require('./routes/auth');
const incomeRoutes = require('./routes/income');
const expenseRoutes = require('./routes/expense');
const analyticsRoutes = require('./routes/analytics');
const categoryRoutes = require('./routes/category');
const billRoutes = require('./routes/bill');
const debtRoutes = require('./routes/debt');
const groupRoutes = require('./routes/group');
const smsRoutes = require('./routes/sms');
// const marketRoutes = require('./routes/marketRoutes'); // [REMOVED]


const app = express();
app.set('etag', false); // Disable 304 responses

// Connect to Firebase (optional for local development)
try {
  initializeFirebase();
} catch (error) {
  console.log('⚠️  Running without Firebase - local MongoDB only');
}

// Middleware
app.use(cors({
  origin: '*',
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));
app.use(morgan('dev'));
app.use('/uploads', express.static('uploads'));

// Disable caching to prevent 304 responses which break the Flutter app's ApiService
app.use((req, res, next) => {
  res.set('Cache-Control', 'no-store, no-cache, must-revalidate, private');
  // FORCE FRESH REQUEST: Strip conditional headers so Express/Client never thinks it's cached
  delete req.headers['if-none-match'];
  delete req.headers['if-modified-since'];
  next();
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/income', incomeRoutes);
app.use('/api/expenses', expenseRoutes);
app.use('/api/analytics', analyticsRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/bill', billRoutes);
app.use('/api/debts', debtRoutes);
app.use('/api/groups', groupRoutes);
app.use('/api/sms', smsRoutes);
// app.use('/api/market', marketRoutes); // [REMOVED] TradingView Routes
app.use('/api/kyc', require('./routes/kyc'));
app.use('/api/statement', require('./routes/statement'));
app.use('/api/tax', require('./routes/tax'));
app.use('/api/markets', require('./routes/markets'));
app.use('/api/chat', require('./routes/chat'));

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', message: 'F Buddy API is running!' });
});

// Test auth endpoint
app.get('/api/test-auth', (req, res) => {
  const token = req.headers.authorization?.split(' ')[1];
  res.json({
    success: true,
    message: 'Auth test endpoint',
    hasAuthHeader: !!req.headers.authorization,
    hasToken: !!token,
    token: token ? token.substring(0, 20) + '...' : null
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    success: false,
    message: 'Something went wrong!',
    error: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: 'Route not found'
  });
});

const PORT = process.env.PORT || 5000;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 F Buddy Server running on port ${PORT}`);
  console.log(`📊 Environment: ${process.env.NODE_ENV}`);
  console.log(`🌐 Network: Accessible on all interfaces (0.0.0.0:${PORT})`);
});

module.exports = app;
