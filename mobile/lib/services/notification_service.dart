import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
    print('[Notifications] Service initialized');
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('[Notifications] Tapped: ${response.payload}');
    // You can navigate to specific screen based on payload
  }

  /// Show transaction detected notification
  Future<void> showTransactionDetected({
    required double amount,
    required String merchant,
    required String type,
    required bool autoSaved,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'sms_transactions',
      'SMS Transactions',
      channelDescription: 'Notifications for SMS-detected transactions',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF6C63FF),
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = autoSaved
        ? '💰 Transaction Auto-Saved'
        : '📝 Review Transaction';

    final body = autoSaved
        ? '₹$amount ${type == 'expense' ? 'spent at' : 'received from'} $merchant'
        : '₹$amount ${type == 'expense' ? 'spent at' : 'received from'} $merchant - Tap to review';

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      details,
      payload: 'transaction_${DateTime.now().millisecondsSinceEpoch}',
    );

    print('[Notifications] Shown: $title - $body');
  }

  /// Show error notification
  Future<void> showError(String message) async {
    const androidDetails = AndroidNotificationDetails(
      'sms_errors',
      'SMS Errors',
      channelDescription: 'Error notifications for SMS processing',
      importance: Importance.low,
      priority: Priority.low,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      '❌ SMS Processing Error',
      message,
      details,
    );
  }

  /// Show bulk import notification
  Future<void> showBulkImportComplete(int count) async {
    const androidDetails = AndroidNotificationDetails(
      'sms_bulk_import',
      'SMS Bulk Import',
      channelDescription: 'Bulk import completion notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF4CAF50),
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      '✅ Import Complete',
      'Successfully imported $count transactions from SMS',
      details,
    );
  }

  /// Generic helper to show a finance notification (ensures init first).
  Future<void> _showFinance({
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    Color color = const Color(0xFFD4A574),
    String? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Finzo $channelName',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: color,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      details,
      payload: payload,
    );
    print('[Notifications] Shown: $title - $body');
  }

  /// Personal expense added.
  Future<void> showExpenseAdded({required double amount, required String category}) async {
    await _showFinance(
      channelId: 'expenses',
      channelName: 'Expenses',
      title: 'Expense added',
      body: 'Rs ${amount.toStringAsFixed(0)} added under $category.',
      payload: 'expense',
    );
  }

  /// Income added.
  Future<void> showIncomeAdded({required double amount, required String source}) async {
    await _showFinance(
      channelId: 'income',
      channelName: 'Income',
      title: 'Income added',
      body: 'Rs ${amount.toStringAsFixed(0)} added from $source.',
      color: const Color(0xFF059669),
      payload: 'income',
    );
  }

  /// A group expense was added and the user owes a share.
  Future<void> showGroupExpenseAdded({
    required String groupName,
    required String description,
    required double yourShare,
  }) async {
    await _showFinance(
      channelId: 'group_expenses',
      channelName: 'Group Expenses',
      title: 'New expense in $groupName',
      body: yourShare > 0
          ? '$description - your share is Rs ${yourShare.toStringAsFixed(0)}.'
          : '$description was added.',
      payload: 'group_expense',
    );
  }

  /// Reminder that the user still owes money in a group.
  Future<void> showSettleReminder({
    required String groupName,
    required double amount,
    required String toName,
  }) async {
    await _showFinance(
      channelId: 'settle_reminders',
      channelName: 'Settle Reminders',
      title: 'Time to settle up in $groupName',
      body: 'You owe Rs ${amount.toStringAsFixed(0)} to $toName. Tap to settle.',
      color: const Color(0xFFD97706),
      payload: 'settle',
    );
  }

  /// A settlement was completed.
  Future<void> showSettlementDone({
    required double amount,
    required String toName,
  }) async {
    await _showFinance(
      channelId: 'settlements',
      channelName: 'Settlements',
      title: 'Settled up',
      body: 'You settled Rs ${amount.toStringAsFixed(0)} with $toName.',
      color: const Color(0xFF059669),
      payload: 'settlement_done',
    );
  }

  /// Request notification permissions (Android 13+)
  Future<bool> requestPermissions() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }

    return true; // iOS handles permissions in initialization
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}


