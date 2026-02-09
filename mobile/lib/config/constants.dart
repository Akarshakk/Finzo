import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  // ====================================================================
  // NETWORK CONFIGURATION FOR SMS TESTING
  // ====================================================================
  //
  // IMPORTANT: Update this when testing on real Android device!
  //
  // OPTION 1: Development (Default)
  // - Use 'localhost' for web/iOS simulator
  // - Use '10.0.2.2' for Android emulator
  //
  // OPTION 2: Real Android Device (Same Wi-Fi)
  // - Find your computer's IP: `ipconfig getifaddr en0` (macOS)
  // - Replace 'localhost' below with your IP (e.g., '192.168.1.100')
  //
  // OPTION 3: USB Reverse Proxy
  // - Run: `adb reverse tcp:5001 tcp:5001`
  // - Use 'localhost' (Android will forward to computer)
  // ====================================================================

  // 🔧 CHANGE THIS BASED ON YOUR PLATFORM:
  // For Web/Emulator: 'localhost'
  // For Physical Device: Your computer's IP (e.g., '10.176.182.25')
  static const String _serverIp = '192.168.1.246'; // Your computer's IP for physical device
  static const String _serverPort = '5001'; // Backend runs on port 5001 (from .env)

  // Automatically detect platform and use correct URL
  static String get baseUrl {
    // For web browser - always use localhost
    if (kIsWeb) {
      return 'http://localhost:$_serverPort/api';
    }

    // For mobile platforms - use the configured IP
    // Note: Android emulator needs 10.0.2.2 to reach host machine
    // For physical devices, set _serverIp to your computer's IP
    if (_serverIp == 'localhost' || _serverIp == '127.0.0.1') {
      // This handles Android emulator - it needs 10.0.2.2
      // iOS simulator works with localhost
      return 'http://10.0.2.2:$_serverPort/api';
    }

    // For real devices (physical Android/iOS) using computer's IP
    return 'http://$_serverIp:$_serverPort/api';
  }

  // Auth endpoints
  static const String register = '/auth/register';
  static const String verifyEmail = '/auth/verify-email';
  static const String resendOtp = '/auth/resend-otp';
  static const String login = '/auth/login';
  static const String me = '/auth/me';
  static const String updateProfile = '/auth/update';
  static const String updatePassword = '/auth/password';

  // Income endpoints
  static const String income = '/income';
  static const String currentIncome = '/income/current';

  // Expense endpoints
  static const String expenses = '/expenses';
  static const String latestExpenses = '/expenses/latest';
  static const String checkDuplicate = '/expenses/check-duplicate';

  // Analytics endpoints
  static const String categoryAnalytics = '/analytics/category';
  static const String summary = '/analytics/summary';
  static const String balanceChart = '/analytics/balance-chart';
  static const String dashboard = '/analytics/dashboard';

  // Category endpoints
  static const String categories = '/categories';

  // Bill scanning endpoints
  static const String billScan = '/bill/scan';
  static const String billScanBase64 = '/bill/scan-base64';

  // Tax calculation endpoints
  static const String taxSave = '/tax/save';
  static const String taxHistory = '/tax';
  static const String taxLatest = '/tax/latest';
}

class StorageKeys {
  static const String token = 'auth_token';
  static const String user = 'user_data';
  static const String isFirstTime = 'is_first_time';
}


