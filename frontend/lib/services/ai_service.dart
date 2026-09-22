import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AiService {
  static final AiService instance = AiService._internal();
  AiService._internal();

  // ⚠️ Android emulator: 10.0.2.2 | iOS sim: localhost | Real device: your PC IP
  static const String _baseUrl = 'http://10.0.2.2:8000';

  /// Send a message to the Ori chatbot backend.
  Future<String> chat({
    required String message,
    List<Map<String, dynamic>> history = const [],
  }) async {
    try {
      // Convert Flutter history format → backend format
      final backendHistory = history.map((msg) {
        return {
          'role': msg['isUser'] == true ? 'user' : 'model',
          'content': msg['text'] as String,
        };
      }).toList();

      // Get Firebase ID token (optional — only if backend verifies auth)
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();

      final response = await http
          .post(
            Uri.parse('$_baseUrl/chat'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'message': message,
              'history': backendHistory,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] as String;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to reach AI: $e');
    }
  }
}