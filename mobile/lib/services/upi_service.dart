import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Handles UPI settlement via deep links.
///
/// Instead of a payment gateway (like Razorpay), we build a standard `upi://pay`
/// intent. On Android this opens the system chooser listing every UPI app the
/// user has installed (Google Pay, PhonePe, Paytm, BHIM, etc.) so they can
/// complete the payment inside their preferred app.
class UpiService {
  /// Removes non-ASCII / problematic characters that break UPI deep links in
  /// several apps (e.g. bullet '·', emojis, currency symbols).
  static String _asciiSafe(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim();
    // Collapse repeated whitespace.
    return cleaned.replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Builds a UPI deep-link URI following the NPCI UPI URL spec.
  ///
  /// IMPORTANT: We build the query string manually with Uri.encodeComponent so
  /// spaces become %20 (not '+'). Dart's default Uri(queryParameters:) uses
  /// application/x-www-form-urlencoded ('+') encoding, which many UPI apps
  /// (PhonePe, Paytm) reject, causing "unable to pay" even though the amount
  /// shows correctly.
  static Uri buildUpiUri({
    required String payeeUpiId,
    required String payeeName,
    required double amount,
    String note = 'Finzo settlement',
  }) {
    // Amount must be a plain 2-decimal number string, e.g. "100.00".
    final amountStr = amount.toStringAsFixed(2);

    final params = <String, String>{
      'pa': payeeUpiId.trim(),
      'pn': _asciiSafe(payeeName).isEmpty ? 'Payee' : _asciiSafe(payeeName),
      'am': amountStr,
      'cu': 'INR',
      'tn': _asciiSafe(note).isEmpty ? 'Finzo settlement' : _asciiSafe(note),
    };

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return Uri.parse('upi://pay?$query');
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
