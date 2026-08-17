const nodemailer = require('nodemailer');
const otpGenerator = require('otp-generator');

// In-memory store for OTPs (Use Redis in production)
const otpStore = new Map();

// Optional SMTP transporter (used only as a fallback for local dev, since many
// hosts like Render block outbound SMTP ports).
let transporter = null;

const createTransporter = () => {
    try {
        if (!process.env.SMTP_EMAIL || !process.env.SMTP_PASSWORD) {
            return null;
        }

        return nodemailer.createTransport({
            host: process.env.SMTP_HOST || 'smtp.gmail.com',
            port: parseInt(process.env.SMTP_PORT) || 587,
            secure: false,
            pool: true,
            maxConnections: 2,
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

// Build the OTP email HTML
const buildOtpHtml = (otp) => `
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
`;

const getSender = () => ({
    email: process.env.EMAIL_FROM || process.env.SMTP_EMAIL || 'no-reply@finzo.app',
    name: process.env.EMAIL_FROM_NAME || 'Finzo Security',
});

/**
 * Sends the OTP email via the SendGrid HTTPS API (port 443, works on Render).
 * Uses "Single Sender Verification" - no domain required.
 * Returns true on success, false otherwise.
 */
const sendViaSendGrid = async (email, otp) => {
    const apiKey = process.env.SENDGRID_API_KEY;
    if (!apiKey) return false;

    const sender = getSender();

    try {
        const res = await fetch('https://api.sendgrid.com/v3/mail/send', {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${apiKey}`,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                personalizations: [{ to: [{ email }] }],
                from: { email: sender.email, name: sender.name },
                subject: 'Your Verification Code - Finzo',
                content: [{ type: 'text/html', value: buildOtpHtml(otp) }],
            }),
        });

        // SendGrid returns 202 Accepted on success.
        if (res.ok) {
            console.log(`[MFA] ✓ OTP email sent via SendGrid to ${email}`);
            return true;
        }

        const errText = await res.text();
        console.error(`[MFA] SendGrid API error (${res.status}): ${errText}`);
        return false;
    } catch (error) {
        console.error('[MFA] SendGrid request failed:', error.message);
        return false;
    }
};

/**
 * Sends the OTP email via the Brevo (Sendinblue) HTTPS API.
 * Uses port 443, so it works on hosts that block SMTP (e.g. Render free tier).
 * Returns true on success, false otherwise.
 */
const sendViaBrevo = async (email, otp) => {
    const apiKey = process.env.BREVO_API_KEY;
    if (!apiKey) return false;

    // Sender must be a verified sender in your Brevo account.
    const senderEmail = process.env.EMAIL_FROM || process.env.SMTP_EMAIL || 'no-reply@finzo.app';
    const senderName = process.env.EMAIL_FROM_NAME || 'Finzo Security';

    try {
        const res = await fetch('https://api.brevo.com/v3/smtp/email', {
            method: 'POST',
            headers: {
                'accept': 'application/json',
                'content-type': 'application/json',
                'api-key': apiKey,
            },
            body: JSON.stringify({
                sender: { name: senderName, email: senderEmail },
                to: [{ email }],
                subject: 'Your Verification Code - Finzo',
                htmlContent: buildOtpHtml(otp),
            }),
        });

        if (res.ok) {
            console.log(`[MFA] ✓ OTP email sent via Brevo to ${email}`);
            return true;
        }

        const errText = await res.text();
        console.error(`[MFA] Brevo API error (${res.status}): ${errText}`);
        return false;
    } catch (error) {
        console.error('[MFA] Brevo request failed:', error.message);
        return false;
    }
};

/**
 * Fallback: send via SMTP (local dev only; blocked on many hosts).
 */
const sendViaSmtp = async (email, otp) => {
    if (!transporter) {
        transporter = createTransporter();
    }
    if (!transporter) return false;

    try {
        await transporter.sendMail({
            from: `"Finzo Security" <${process.env.SMTP_EMAIL}>`,
            to: email,
            subject: 'Your Verification Code - Finzo',
            html: buildOtpHtml(otp),
        });
        console.log(`[MFA] ✓ OTP email sent via SMTP to ${email}`);
        return true;
    } catch (error) {
        console.error('[MFA] SMTP send failed:', error.message);
        return false;
    }
};

/**
 * Generates and sends an OTP to the user's email.
 * The code is stored synchronously before any network call, so verification
 * works immediately even while the email is still being delivered.
 * @param {string} userId - User ID (or email key)
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

    // Store OTP with expiry (10 mins) - synchronous, happens before network I/O
    otpStore.set(userId, {
        code: otp,
        expires: Date.now() + 10 * 60 * 1000
    });

    // Always log OTP for development/testing (visible in Render logs)
    console.log('=============================================');
    console.log(`[MFA] GENERATED OTP FOR ${email}: ${otp}`);
    console.log(`[MFA] User ID: ${userId}`);
    console.log(`[MFA] Expires in 10 minutes`);
    console.log('=============================================');

    // Prefer an HTTPS email API (works on Render, which blocks SMTP).
    // Try SendGrid, then Brevo, then fall back to SMTP (local dev only).
    let sent = await sendViaSendGrid(email, otp);
    if (!sent) sent = await sendViaBrevo(email, otp);
    if (!sent) sent = await sendViaSmtp(email, otp);
    if (!sent) {
        console.warn('[MFA] ⚠️ Email not sent (no working provider). Use the OTP from the log above.');
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
