import 'dart:convert';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:http/http.dart' as http;

class AiService {
  static final AiService instance = AiService._internal();
  AiService._internal();

  // ============================================================
  // ✅ Dynamic Base URL
  // ============================================================
  String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  // ============================================================
  // 1. Ori Chatbot
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

      final response = await http
          .post(
            Uri.parse('$baseUrl/chat'),
            headers: {'Content-Type': 'application/json'},
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
        throw Exception(
            'Server error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to reach AI: $e');
    }
  }

  // ============================================================
  // 2. Upload PDF
  // ============================================================
  Future<Map<String, dynamic>> uploadPdf({
    required List<int> fileBytes,
    required String filename,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload-pdf'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: filename,
        ),
      );

      final streamed =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
            'Upload failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }

  // ============================================================
  // 3. Chat with PDF
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
            Uri.parse('$baseUrl/chat-with-pdf'),
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
            'Chat failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception('PDF chat error: $e');
    }
  }

  // ============================================================
  // 4. Transcribe Audio (Voice Input)
  // ============================================================
  Future<String> transcribeAudio({
    required List<int> audioBytes,
    required String filename,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/voice/transcribe?language=en'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'audio',
          audioBytes,
          filename: filename,
        ),
      );

      final streamed =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['transcript'] as String;
      } else {
        throw Exception(
            'Transcribe failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception('Transcription error: $e');
    }
  }

  // ============================================================
  // 5. Ingest Pasted Text → doc_id (RAG — backend port 8001)
  // ============================================================
  String get _ragBaseUrl {
    if (kIsWeb) return 'http://localhost:8001';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8001';
    }
    return 'http://localhost:8001';
  }

  Future<Map<String, dynamic>?> ingestText({
    required String text,
    String title = 'Pasted Text',
  }) async {
    try {
      debugPrint('[AI] POST $_ragBaseUrl/api/ai/ingest-text');
      final r = await http
          .post(
            Uri.parse('$_ragBaseUrl/api/ai/ingest-text'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': text,
              'title': title,
              'user_id': 'anonymous',
            }),
          )
          .timeout(const Duration(seconds: 120));

      debugPrint('[AI] ingest-text status: ${r.statusCode}');
      if (r.statusCode != 200) {
        debugPrint('[AI] ingest-text error: ${r.body}');
        return null;
      }
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[AI] ingestText exception: $e');
      return null;
    }
  }
}