import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/constants.dart';

class BillScanResult {
  final String? rawText;
  final double? amount;
  final String? category;
  final String? date;
  final String? merchant;
  final double? confidence;

  BillScanResult({
    this.rawText,
    this.amount,
    this.category,
    this.date,
    this.merchant,
    this.confidence,
  });

  factory BillScanResult.fromJson(Map<String, dynamic> json) {
    // Handle amount safely (can be String or num)
    double? parsedAmount;
    if (json['amount'] != null) {
      if (json['amount'] is num) {
        parsedAmount = (json['amount'] as num).toDouble();
      } else if (json['amount'] is String) {
         // Remove currency symbols and parse
         String cleaned = json['amount'].toString().replaceAll(RegExp(r'[^0-9.]'), '');
         parsedAmount = double.tryParse(cleaned);
      }
    }

    return BillScanResult(
      rawText: json['rawText'], // RAG service might not return this, optional
      amount: parsedAmount,
      category: json['category'],
      date: json['date'],
      merchant: json['merchant'],
      confidence: json['confidence']?.toDouble(),
    );
  }
}

class BillScanService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<String?> _getToken() async {
    return await _storage.read(key: StorageKeys.token);
  }

  /// Scan a bill image from bytes using RAG Service (Port 5002) via Multipart request
  static Future<Map<String, dynamic>> scanBillFromBytes(Uint8List imageBytes) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated'
        };
      }

      // Construct RAG Service URL (Port 5002)
      // Logic mirrors ApiService.scanBill to check for local dev vs production URL
      String ragUrl = ApiConstants.baseUrl.replaceAll('5001', '5002').replaceAll('/api', '/scan-bill');
      
      // Fallback for local development if baseUrl doesn't have port (e.g. standard domain)
      // or if logic fails. For emulators, this handles localhost mapping.
      if (!ragUrl.contains('5002')) {
        // Assuming typical emulator/device setup if port replacement failed
         ragUrl = ApiConstants.baseUrl.contains('10.0.2.2') 
            ? 'http://10.0.2.2:5002/scan-bill' 
            : 'http://192.168.1.246:5002/scan-bill';
      }

      print('[BillScanService] URL: $ragUrl');

      // Create Multipart Request
      var request = http.MultipartRequest('POST', Uri.parse(ragUrl));
      
      // Add file
      request.files.add(http.MultipartFile.fromBytes(
        'file', 
        imageBytes, 
        filename: 'bill.jpg'
      ));

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('[BillScanService] Status: ${response.statusCode}');
      print('[BillScanService] Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // RAG service returns data in 'data' field
          return {
            'success': true,
            'data': BillScanResult.fromJson(data['data']),
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to scan bill'
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('[BillScanService] Error: $e');
      return {
        'success': false,
        'message': 'Error scanning bill: ${e.toString()}'
      };
    }
  }

  /// Scan a bill from base64 encoded image
  /// Decodes to bytes and uses the multipart endpoint
  static Future<Map<String, dynamic>> scanBillBase64(String base64Image) async {
    try {
      // Decode base64 to bytes
      Uint8List bytes = base64Decode(base64Image);
      return await scanBillFromBytes(bytes);
    } catch (e) {
      return {
        'success': false,
        'message': 'Error decoding image: ${e.toString()}'
      };
    }
  }
}


