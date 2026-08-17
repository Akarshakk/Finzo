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
  // Local-dev IP only. Production builds ignore this and use the
  // API_BASE_URL dart-define instead (see _prodBaseUrl below).
  static const String _serverIp = '192.168.1.246'; // Your computer's IP for physical device
  static const String _serverPort = '5001'; // Backend runs on port 5001 (from .env)

  // Production backend URL (deployed on Render). This is used by default on all
  // platforms so builds "just work" without extra flags. To temporarily point at
  // a different backend (e.g. local dev), override at build time:
  //   flutter run --dart-define=API_BASE_URL=http://192.168.1.246:5001/api
  static const String _prodBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://finzo-a6k2.onrender.com/api',
  );

  // Optional separate override for the Python RAG service (bill scan / chat context).
  static const String _prodRagBaseUrl =
      String.fromEnvironment('RAG_BASE_URL', defaultValue: '');

  /// Base URL for the Python RAG service (port 5002 in local dev).
  static String get ragBaseUrl {
    if (_prodRagBaseUrl.isNotEmpty) return _prodRagBaseUrl;
    // Local dev: derive from the API host by swapping the port.
    return baseUrl.replaceAll(':$_serverPort/api', ':5002');
  }

  // Automatically detect platform and use correct URL
  static String get baseUrl => _normalizeUrl(_resolveBaseUrl());

  static String _resolveBaseUrl() {
    // Production build with an explicit backend URL wins everywhere.
    if (_prodBaseUrl.isNotEmpty) return _prodBaseUrl;

    // For web browser - always use localhost
    if (kIsWeb) {
      return 'http://localhost:$_serverPort/api';
    }

    // For mobile platforms
    // If _serverIp is localhost, it works for:
    // 1. iOS Simulator (direct)
    // 2. Android Physical Device (via 'adb reverse tcp:5001 tcp:5001')
    // 3. Android Emulator (needs 10.0.2.2)
    
    if (_serverIp == 'localhost' || _serverIp == '127.0.0.1') {
      return 'http://localhost:$_serverPort/api';
    }

    // For real devices (physical Android/iOS) using computer's IP
    return 'http://$_serverIp:$_serverPort/api';
  }

  /// Collapses accidental double slashes (e.g. ".com//api") and strips any
  /// trailing slash, while preserving the "https://" scheme. This keeps request
  /// URLs valid even if the configured base URL has stray slashes.
  static String _normalizeUrl(String url) {
    final schemeIndex = url.indexOf('://');
    if (schemeIndex == -1) {
      return url.replaceAll(RegExp(r'/{2,}'), '/').replaceAll(RegExp(r'/+$'), '');
    }
    final scheme = url.substring(0, schemeIndex + 3);
    var rest = url.substring(schemeIndex + 3).replaceAll(RegExp(r'/{2,}'), '/');
    rest = rest.replaceAll(RegExp(r'/+$'), '');
    return scheme + rest;
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
