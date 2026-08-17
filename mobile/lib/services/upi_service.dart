import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Handles UPI settlement via deep links.
///
/// Instead of a payment gateway (like Razorpay), we build a standard `upi://pay`
/// intent. On Android this opens the system chooser listing every UPI app the
/// user has installed (Google Pay, PhonePe, Paytm, BHIM, etc.) so they can
/// complete the payment inside their preferred app.
class UpiService {
  /// Builds a UPI deep-link URI following the NPCI UPI URL spec.
  static Uri buildUpiUri({
    required String payeeUpiId,
    required String payeeName,
    required double amount,
    String note = 'Finzo settlement',
  }) {
    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': payeeUpiId.trim(),
        'pn': payeeName.trim(),
        'am': amount.toStringAsFixed(2),
        'cu': 'INR',
        'tn': note,
      },
    );
  }

  /// Basic sanity check for a UPI VPA, e.g. `name@bank`.
  static bool isValidUpiId(String? upiId) {
    if (upiId == null) return false;
    final value = upiId.trim();
    final regex = RegExp(r'^[\w.\-]{2,256}@[a-zA-Z]{2,64}$');
    return regex.hasMatch(value);
  }

  /// Launches an installed UPI app for the given payment.
  ///
  /// Returns true if a UPI app was opened, false otherwise (e.g. no UPI app
  /// installed or the platform does not support the `upi://` scheme, such as web).
  static Future<bool> payViaUpi({
    required String payeeUpiId,
    required String payeeName,
    required double amount,
    String note = 'Finzo settlement',
  }) async {
    final uri = buildUpiUri(
      payeeUpiId: payeeUpiId,
      payeeName: payeeName,
      amount: amount,
      note: note,
    );

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      // Fallback: try launching anyway; some devices report false negatives.
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
