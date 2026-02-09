import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import 'api_service.dart';

/// SmartChatService - Hybrid chat service that combines:
/// 1. Main backend /api/chat for CRUD operations (always works)
/// 2. Optional RAG service on port 5002 for PDF knowledge context
class SmartChatService {
  // RAG service URL (optional - for PDF context) - uses same IP as main backend
  static const String _ragBaseUrl = 'http://192.168.1.246:5002';
  
  /// Check if RAG service is available
  static Future<bool> isRagAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$_ragBaseUrl/health'),
      ).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get context from RAG service (PDF knowledge)
  static Future<String?> _getRagContext(String query) async {
    try {
      final response = await http.post(
        Uri.parse('$_ragBaseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['answer'] != null) {
          return data['answer'];
        }
      }
    } catch (e) {
      print('[SmartChat] RAG context unavailable: $e');
    }
    return null;
  }

  /// Send a chat query - uses main backend, optionally enriched with RAG context
  static Future<ChatResponse> chat(String query, {Map<String, dynamic>? context, List<Map<String, String>>? conversationHistory}) async {
    try {
      final url = '${ApiConstants.baseUrl}/chat';
      print('[SmartChat] Sending query to $url: $query');
      
      // Try to get RAG context if available (for advisory/knowledge queries)
      String? ragContext;
      final isRag = await isRagAvailable();
      if (isRag) {
        ragContext = await _getRagContext(query);
        if (ragContext != null) {
          print('[SmartChat] Got RAG context: ${ragContext.substring(0, ragContext.length.clamp(0, 100))}...');
        }
      }
      
      final token = await ApiService.getToken();
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'query': query,
          if (context != null) 'context': context,
          if (ragContext != null) 'ragContext': ragContext,
          if (conversationHistory != null) 'conversationHistory': conversationHistory,
        }),
      ).timeout(const Duration(seconds: 120)); // Increased for AI rate limits

      print('[SmartChat] Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ChatResponse.fromJson(data);
      } else {
        // Try to parse error message from backend
        String errorMessage = 'Server error: ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (_) {
          // Fallback to default message
        }
        
        return ChatResponse(
          success: false,
          type: 'error',
          message: errorMessage,
        );
      }
    } catch (e) {
      print('[SmartChat] Error: $e');
      return ChatResponse(
        success: false,
        type: 'error',
        message: 'Connection error. Please check your internet.',
      );
    }
  }

  /// Execute a confirmed action (called after user confirms a CRUD operation)
  static Future<ChatResponse> executeAction(String action, Map<String, dynamic> params) async {
    try {
      final url = '${ApiConstants.baseUrl}/chat/execute';
      print('[SmartChat] Executing action: $action');
      
      final token = await ApiService.getToken();
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'action': action,
          'params': params,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ChatResponse(
          success: data['success'] ?? false,
          type: 'data',
          message: data['message'] ?? 'Action completed',
        );
      } else {
        return ChatResponse(
          success: false,
          type: 'error',
          message: 'Failed to execute action',
        );
      }
    } catch (e) {
      print('[SmartChat] Execute error: $e');
      return ChatResponse(
        success: false,
        type: 'error',
        message: 'Error: ${e.toString()}',
      );
    }
  }

  /// Check backend health
  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/health'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

/// Response from the chat API
class ChatResponse {
  final bool success;
  final String type; // 'data', 'confirmation', 'action', 'error'
  final String message;
  final String? action; // For confirmation/action type
  final Map<String, dynamic>? params; // For confirmation type
  final Map<String, dynamic>? data; // For data type
  final List<String> sources;

  ChatResponse({
    required this.success,
    required this.type,
    required this.message,
    this.action,
    this.params,
    this.data,
    this.sources = const [],
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      success: json['success'] ?? false,
      type: json['type'] ?? 'data',
      message: json['message'] ?? '',
      action: json['action'],
      params: json['params'],
      data: json['data'],
      sources: json['sources'] != null 
          ? List<String>.from(json['sources']) 
          : [],
    );
  }

  bool get needsConfirmation => type == 'confirmation';
  bool get hasAction => type == 'action' && action != null;
  
  /// Alias for message - for backward compatibility
  String get answer => message;
}

/// RAG service statistics (when port 5002 is running)
class RagStats {
  final int totalVectors;
  final int dimension;
  final String indexName;

  RagStats({
    required this.totalVectors,
    required this.dimension,
    required this.indexName,
  });

  factory RagStats.fromJson(Map<String, dynamic> json) {
    return RagStats(
      totalVectors: json['total_vectors'] ?? 0,
      dimension: json['dimension'] ?? 384,
      indexName: json['index_name'] ?? '',
    );
  }
}

/// Get RAG stats if service is available
Future<RagStats?> getRagStats() async {
  try {
    final response = await http.get(
      Uri.parse('http://10.0.2.2:5002/stats'),
    ).timeout(const Duration(seconds: 3));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return RagStats.fromJson(data);
    }
  } catch (e) {
    print('[SmartChat] RAG stats unavailable: $e');
  }
  return null;
}
