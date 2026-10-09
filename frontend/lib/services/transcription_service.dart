import 'dart:convert';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

class TranscriptionService {
  static final TranscriptionService instance =
      TranscriptionService._internal();
  factory TranscriptionService() => instance;
  TranscriptionService._internal();

  String get _baseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  Future<Map<String, dynamic>> transcribe(
    String audioPath, {
    String language = 'en',
  }) async {
    final uri = Uri.parse('$_baseUrl/api/voice/transcribe?language=$language');
    final req = http.MultipartRequest('POST', uri);

    if (kIsWeb) {
      // On web, audioPath is a blob URL — fetch the bytes
      final blobResponse = await http.get(Uri.parse(audioPath));
      req.files.add(
        http.MultipartFile.fromBytes(
          'audio',
          blobResponse.bodyBytes,
          filename: 'recording.webm',
          contentType: MediaType('audio', 'webm'),
        ),
      );
    } else {
      req.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          audioPath,
          contentType: MediaType('audio', 'mp4'),
        ),
      );
    }

    debugPrint('[Voice] POST $uri');
    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final resp = await http.Response.fromStream(streamed);
    debugPrint('[Voice] status ${resp.statusCode}');
    debugPrint('[Voice] body ${resp.body}');

    if (resp.statusCode != 200) {
      throw Exception('Transcription failed: ${resp.statusCode}');
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}
