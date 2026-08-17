const User = require('../models/User');
const mfaService = require('../services/mfaService');

// Temporary storage for pending registrations (use Redis in production)
const pendingRegistrations = new Map();

// @desc    Register user (Step 1 - stores pending, sends OTP)
// @route   POST /api/auth/register
// @access  Public
exports.register = async (req, res) => {
  try {
    const { name, email, password, monthlyBudget, upiId } = req.body;

    // Check if user already exists in database
    const existingUser = await User.findByEmail(email);
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'User with this email already exists'
      });
    }

    // Check if pending registration exists
    if (pendingRegistrations.has(email.toLowerCase())) {
      // Resend OTP for existing pending registration
      const pending = pendingRegistrations.get(email.toLowerCase());
      await mfaService.sendOTP(email.toLowerCase(), email);

      return res.status(200).json({
        success: true,
        message: 'A verification code has been sent to your email',
        data: {
          email: email,
          requiresVerification: true
        }
      });
    }

    // Store registration data temporarily (NOT in database yet)
    pendingRegistrations.set(email.toLowerCase(), {
      name,
      email: email.toLowerCase(),
      password, // Will be hashed when actually creating user
      monthlyBudget: monthlyBudget || 0,
      upiId: upiId || '',
      createdAt: Date.now(),
      expiresAt: Date.now() + 30 * 60 * 1000 // 30 minutes
    });

    // Send verification OTP
    await mfaService.sendOTP(email.toLowerCase(), email);

    res.status(201).json({
      success: true,
      message: 'Verification code sent! Please check your email.',
      data: {
        email: email,
        requiresVerification: true
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error registering user',
      error: error.message
    });
  }
};

// @desc    Verify email with OTP (Step 2 - creates user in database)
// @route   POST /api/auth/verify-email
// @access  Public
exports.verifyEmail = async (req, res) => {
  try {
    const { email, otp } = req.body;

    if (!email || !otp) {
      return res.status(400).json({
        success: false,
        message: 'Please provide email and OTP'
      });
    }

    const emailLower = email.toLowerCase();

    // Check if pending registration exists
    const pending = pendingRegistrations.get(emailLower);
    if (!pending) {
      return res.status(404).json({
        success: false,
        message: 'No pending registration found. Please register again.'
      });
    }

    // Check if registration expired
    if (Date.now() > pending.expiresAt) {
      pendingRegistrations.delete(emailLower);
      return res.status(400).json({
        success: false,
        message: 'Registration expired. Please register again.'
      });
    }

    // Verify OTP
    const isValid = mfaService.verifyOTP(emailLower, otp);
    if (!isValid) {
      return res.status(400).json({
        success: false,
        message: 'Invalid or expired OTP'
      });
    }

    // OTP verified! Now create the user in database
    const user = await User.createUser({
      name: pending.name,
      email: pending.email,
      password: pending.password,
      monthlyBudget: pending.monthlyBudget,
      upiId: pending.upiId,
      emailVerified: true // Already verified
    });

    // Remove from pending
    pendingRegistrations.delete(emailLower);

    // Generate token
    const token = User.getSignedJwtToken(user.id);

    res.status(200).json({
      success: true,
      message: 'Email verified! Account created successfully.',
      data: {
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          profilePicture: user.profilePicture,
          upiId: user.upiId || '',
          monthlyBudget: user.monthlyBudget,
          savingsTarget: user.savingsTarget,
          emailVerified: true,
          kycStatus: user.kycStatus,
          createdAt: user.createdAt
        },
        token
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error verifying email',
      error: error.message
    });
  }
};

// @desc    Resend verification OTP
// @route   POST /api/auth/resend-otp
// @access  Public
exports.resendOtp = async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({
        success: false,
        message: 'Please provide email'
      });
    }

    const emailLower = email.toLowerCase();

    // Check pending registrations first
    const pending = pendingRegistrations.get(emailLower);
    if (pending) {
      // Check if expired
      if (Date.now() > pending.expiresAt) {
        pendingRegistrations.delete(emailLower);
        return res.status(400).json({
          success: false,
          message: 'Registration expired. Please register again.'
        });
      }

      // Extend expiry and send new OTP
      pending.expiresAt = Date.now() + 30 * 60 * 1000;
      await mfaService.sendOTP(emailLower, email);

      return res.status(200).json({
        success: true,
        message: 'New OTP sent to your email'
      });
    }

    // Check if user exists but not verified (legacy case)
    const user = await User.findByEmail(email);
    if (user && !user.emailVerified) {
      await mfaService.sendOTP(user.id, user.email);
      return res.status(200).json({
        success: true,
        message: 'New OTP sent to your email'
      });
    }

    if (user && user.emailVerified) {
      return res.status(400).json({
        success: false,
        message: 'Email is already verified'
      });
    }

    return res.status(404).json({
      success: false,
      message: 'No pending registration found. Please register first.'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error sending OTP',
      error: error.message
    });
  }
};

// @desc    Login user
// @route   POST /api/auth/login
// @access  Public
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Please provide email and password'
      });
    }

    // Check for user
    const user = await User.findByEmail(email, true);

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }

    // Check if password matches
    const isMatch = await User.matchPassword(password, user.password);

    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }

    // Generate token
    const token = User.getSignedJwtToken(user.id);

    res.status(200).json({
      success: true,
      message: 'Login successful',
      data: {
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          profilePicture: user.profilePicture,
          upiId: user.upiId || '',
          monthlyBudget: user.monthlyBudget,
          savingsTarget: user.savingsTarget,
          emailVerified: user.emailVerified,
          kycStatus: user.kycStatus,
          createdAt: user.createdAt
        },
        token
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error logging in',
      error: error.message
    });
  }
};

// @desc    Get current logged in user
// @route   GET /api/auth/me
// @access  Private
exports.getMe = async (req, res) => {
  try {
    const user = await User.findById(req.user.id);

    res.status(200).json({
      success: true,
      data: {
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          profilePicture: user.profilePicture,
          upiId: user.upiId || '',
          monthlyBudget: user.monthlyBudget,
          savingsTarget: user.savingsTarget,
          emailVerified: user.emailVerified,
          kycStatus: user.kycStatus,
          createdAt: user.createdAt
        }
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching user',
      error: error.message
    });
  }
};

// @desc    Update user profile
// @route   PUT /api/auth/update
// @access  Private
exports.updateProfile = async (req, res) => {
  try {
    const { name, monthlyBudget, savingsTarget, profilePicture, upiId } = req.body;

    const updateData = {};
    if (name) updateData.name = name;
    if (monthlyBudget !== undefined) updateData.monthlyBudget = monthlyBudget;
    if (savingsTarget !== undefined) updateData.savingsTarget = savingsTarget;
    if (profilePicture !== undefined) updateData.profilePicture = profilePicture;
    if (upiId !== undefined) updateData.upiId = (upiId || '').trim();

    const user = await User.updateUser(req.user.id, updateData);

    res.status(200).json({
      success: true,
      message: 'Profile updated successfully',
      data: {
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          profilePicture: user.profilePicture,
          upiId: user.upiId || '',
          monthlyBudget: user.monthlyBudget,
          savingsTarget: user.savingsTarget,
          emailVerified: user.emailVerified,
          kycStatus: user.kycStatus,
          createdAt: user.createdAt
        }
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error updating profile',
      error: error.message
    });
  }
};

// @desc    Update password
// @route   PUT /api/auth/password
// @access  Private
exports.updatePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    const user = await User.findById(req.user.id, true);

    const isMatch = await User.matchPassword(currentPassword, user.password);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Current password is incorrect'
      });
    }

    await User.updateUser(req.user.id, { password: newPassword });

    const token = User.getSignedJwtToken(user.id);

    res.status(200).json({
      success: true,
      message: 'Password updated successfully',
      data: { token }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error updating password',
      error: error.message
    });
  }
};

// Cleanup expired pending registrations periodically
setInterval(() => {
  const now = Date.now();
  for (const [email, data] of pendingRegistrations) {
    if (now > data.expiresAt) {
      pendingRegistrations.delete(email);
      console.log(`[Auth] Cleaned up expired pending registration: ${email}`);
    }
  }
}, 5 * 60 * 1000); // Every 5 minutes
