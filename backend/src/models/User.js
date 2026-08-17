const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { getDb } = require('../config/firebase');
const { serializeDoc } = require('../utils/firestore');

const COLLECTION_NAME = 'users';

// User schema definition (for validation reference)
const userFields = {
  name: { type: 'string', required: true, maxLength: 50 },
  email: { type: 'string', required: true, unique: true },
  password: { type: 'string', required: true, minLength: 6 },
  profilePicture: { type: 'string', default: null },
  monthlyBudget: { type: 'number', default: 0 },
  savingsTarget: { type: 'number', default: 0, min: 0, max: 100 },
  kycStatus: { type: 'string', enum: ['NOT_STARTED', 'PENDING', 'VERIFIED', 'FAILED'], default: 'NOT_STARTED' },
  kycStep: { type: 'number', default: 0 },
  createdAt: { type: 'timestamp', default: () => new Date() }
};

// Hash password
const hashPassword = async (password) => {
  const salt = await bcrypt.genSalt(8);
  return await bcrypt.hash(password, salt);
};

// Compare passwords
const matchPassword = async (enteredPassword, hashedPassword) => {
  return await bcrypt.compare(enteredPassword, hashedPassword);
};

// Generate JWT token
const getSignedJwtToken = (userId) => {
  return jwt.sign({ id: userId }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRE
  });
};

// Create a new user
const createUser = async (userData) => {
  const db = getDb();

  // Hash password before saving
  const hashedPassword = await hashPassword(userData.password);

  const user = {
    name: userData.name?.trim() || '',
    email: userData.email?.toLowerCase() || '',
    password: hashedPassword,
    profilePicture: userData.profilePicture || null,
    upiId: userData.upiId?.trim() || '',
    monthlyBudget: userData.monthlyBudget || 0,
    savingsTarget: userData.savingsTarget || 0,
    emailVerified: userData.emailVerified || false,
    kycStatus: 'NOT_STARTED',
    kycStep: 0,
    createdAt: new Date()
  };

  const docRef = await db.collection(COLLECTION_NAME).add(user);
  return { id: docRef.id, ...user, createdAt: user.createdAt.toISOString() };
};

// Find user by email
const findByEmail = async (email, includePassword = false) => {
  const db = getDb();
  const snapshot = await db.collection(COLLECTION_NAME)
    .where('email', '==', email.toLowerCase())
    .limit(1)
    .get();

  if (snapshot.empty) return null;

  const doc = snapshot.docs[0];
  const userData = serializeDoc(doc); // Handles dates

  // Remove password unless explicitly requested
  if (!includePassword) {
    delete userData.password;
  }

  return userData;
};

// Find user by ID
const findById = async (id, includePassword = false) => {
  const db = getDb();
  const doc = await db.collection(COLLECTION_NAME).doc(id).get();

  if (!doc.exists) return null;

  const userData = serializeDoc(doc); // Handles dates

  if (!includePassword) {
    delete userData.password;
  }

  return userData;
};

// Update user
const updateUser = async (id, updateData) => {
  const db = getDb();

  // If password is being updated, hash it
  if (updateData.password) {
    updateData.password = await hashPassword(updateData.password);
  }

  await db.collection(COLLECTION_NAME).doc(id).update(updateData);
  return await findById(id);
};

// Check if email exists
const emailExists = async (email) => {
  const user = await findByEmail(email);
  return user !== null;
};

module.exports = {
  COLLECTION_NAME,
  userFields,
  hashPassword,
  matchPassword,
  getSignedJwtToken,
  createUser,
  findByEmail,
  findById,
  updateUser,
  emailExists
};
