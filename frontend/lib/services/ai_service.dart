import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AiService {
  static final AiService instance = AiService._internal();
  AiService._internal();

  // ⚠️ Android emulator: 10.0.2.2 | iOS sim: localhost | Real device: your PC IP
  static const String _baseUrl = 'http://10.0.2.2:8000';

  // ============================================================
  // Ori Chatbot — general conversation
  // ============================================================
  Future<String> chat({
    required String message,
    List<Map<String, dynamic>> history = const [],
  }) async {
    try {
      final backendHistory = history.map((msg) {
        return {
          'role': msg['isUser'] == true ? 'user' : 'model',
          'content': msg['text'] as String,
        };
      }).toList();

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

  // ============================================================
  // Upload PDF to backend → returns paper_id
  // ============================================================
  Future<Map<String, dynamic>> uploadPdf(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found: $filePath');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/upload-pdf'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('file', filePath),
      );

      final streamed = await request.send().timeout(
            const Duration(seconds: 60),
          );
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Upload failed (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }

  // ============================================================
  // Chat with uploaded PDF → grounded answer
  // ============================================================
  Future<Map<String, dynamic>> chatWithPdf({
    required String paperId,
    required String question,
    List<Map<String, dynamic>> history = const [],
  }) async {
    try {
      final backendHistory = history.map((msg) {
        return {
          'role': msg['isUser'] == true ? 'user' : 'model',
          'content': msg['text'] as String,
        };
      }).toList();

      final response = await http
          .post(
            Uri.parse('$_baseUrl/chat-with-pdf'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'paper_id': paperId,
              'question': question,
              'history': backendHistory,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Chat failed (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('PDF chat error: $e');
    }
  }
}