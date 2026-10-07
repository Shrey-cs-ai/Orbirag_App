import 'dart:convert';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

class VoiceTranscriptionService {
  static final VoiceTranscriptionService instance =
      VoiceTranscriptionService._internal();
  factory VoiceTranscriptionService() => instance;
  VoiceTranscriptionService._internal();

  // ------------------------------------------------------------
  // Platform-aware backend URL
  // ------------------------------------------------------------
  String get _baseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  /// Upload the audio file to our backend and return the transcript.
  /// Returns null on error.
  Future<String?> transcribe(String filePath, {String language = 'en'}) async {
    try {
      final uri =
          Uri.parse('$_baseUrl/api/voice/transcribe?language=$language');

      final request = http.MultipartRequest('POST', uri);

      if (kIsWeb || filePath.startsWith('blob:') || filePath.startsWith('http')) {
        final blobRes = await http.get(Uri.parse(filePath));
        request.files.add(
          http.MultipartFile.fromBytes(
            'audio',
            blobRes.bodyBytes,
            filename: 'voice.m4a',
            contentType: MediaType('audio', 'mp4'),
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'audio',
            filePath,
            contentType: MediaType('audio', 'mp4'),
          ),
        );
      }

      debugPrint('[Voice] POST $uri');
      final streamed =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);

      debugPrint('[Voice] status ${response.statusCode}');
      debugPrint('[Voice] body ${response.body}');

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return (json['transcript'] ?? '').toString();
    } catch (e) {
      debugPrint('[Voice] exception: $e');
      return null;
    }
  }
}