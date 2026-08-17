const nodemailer = require('nodemailer');
const otpGenerator = require('otp-generator');

// In-memory store for OTPs (Use Redis in production)
const otpStore = new Map();

// Create transporter with better error handling
let transporter = null;

const createTransporter = () => {
    try {
        if (!process.env.SMTP_EMAIL || !process.env.SMTP_PASSWORD) {
            console.warn('[MFA] SMTP credentials not configured. OTPs will only be logged to console.');
            return null;
        }

        return nodemailer.createTransport({
            host: process.env.SMTP_HOST || 'smtp.gmail.com',
            port: parseInt(process.env.SMTP_PORT) || 587,
            secure: false,
            pool: true,
            maxConnections: 2,
            // Fail fast instead of hanging if the SMTP server is slow/unreachable.
            connectionTimeout: 10000,
            greetingTimeout: 10000,
            socketTimeout: 20000,
            auth: {
                user: process.env.SMTP_EMAIL,
                pass: process.env.SMTP_PASSWORD,
            },
            tls: {
                rejectUnauthorized: false
            }
        });
    } catch (error) {
        console.error('[MFA] Failed to create email transporter:', error.message);
        return null;
    }
};

/**
 * Generates and sends an OTP to the user's email
 * @param {string} userId - User ID
 * @param {string} email - User Email
 * @returns {Promise<void>}
 */
exports.sendOTP = async (userId, email) => {
    const otp = otpGenerator.generate(6, {
        upperCaseAlphabets: false,
        specialChars: false,
        lowerCaseAlphabets: false,
        digits: true
    });

    // Store OTP with expiry (10 mins)
    otpStore.set(userId, {
        code: otp,
        expires: Date.now() + 10 * 60 * 1000
    });

    // Always log OTP for development/testing
    console.log('=============================================');
    console.log(`[MFA] GENERATED OTP FOR ${email}: ${otp}`);
    console.log(`[MFA] User ID: ${userId}`);
    console.log(`[MFA] Expires in 10 minutes`);
    console.log('=============================================');

    // Try to send email
    if (!transporter) {
        transporter = createTransporter();
    }

    if (transporter) {
        const mailOptions = {
            from: `"Finzo Security" <${process.env.SMTP_EMAIL}>`,
            to: email,
            subject: 'Your Verification Code - Finzo',
            html: `
                <div style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
                    <h2 style="color: #333;">Identity Verification</h2>
                    <p style="color: #666;">Your verification code is:</p>
                    <div style="background: #f5f5f5; padding: 20px; text-align: center; border-radius: 8px; margin: 20px 0;">
                        <h1 style="color: #4CAF50; letter-spacing: 8px; margin: 0; font-size: 36px;">${otp}</h1>
                    </div>
                    <p style="color: #666;">This code will expire in <strong>10 minutes</strong>.</p>
                    <p style="color: #999; font-size: 12px;">If you didn't request this, please ignore this email.</p>
                    <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
                    <p style="color: #999; font-size: 11px;">Finzo - Your Finance Companion</p>
                </div>
            `
        };

        try {
            await transporter.sendMail(mailOptions);
            console.log(`[MFA] ✓ OTP email sent successfully to ${email}`);
        } catch (error) {
            console.warn('[MFA] ⚠️ Email failed to send. Using console OTP instead.');
            console.error('[MFA] Email Error:', error.message);
            // Don't throw - allow flow to continue with console OTP
        }
    } else {
        console.log('[MFA] Email not configured. Use the OTP from console above.');
    }
};

/**
 * Verifies the OTP provided by the user
 * @param {string} userId - User ID
 * @param {string} code - OTP Code
 * @returns {boolean} - True if valid
 */
exports.verifyOTP = (userId, code) => {
    console.log(`[MFA] Verifying OTP for user: ${userId}`);
    console.log(`[MFA] Provided code: ${code}`);

    const storedData = otpStore.get(userId);

    if (!storedData) {
        console.log('[MFA] No OTP found for this user');
        return false;
    }

    if (Date.now() > storedData.expires) {
        console.log('[MFA] OTP has expired');
        otpStore.delete(userId);
        return false;
    }

    console.log(`[MFA] Stored code: ${storedData.code}`);

    if (storedData.code === code) {
        console.log('[MFA] ✓ OTP verified successfully');
        otpStore.delete(userId); // Clear after successful use
        return true;
    }

    console.log('[MFA] ✗ OTP does not match');
    return false;
};
