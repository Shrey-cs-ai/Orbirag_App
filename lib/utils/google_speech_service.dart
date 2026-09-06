import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// OPTIONAL ALTERNATE to [SpeechRecognitionService].
///
/// Google Cloud Speech-to-Text's simple REST `recognize` endpoint is
/// also batch-style like Whisper (record, then upload, then get text
/// back) — its live streaming API requires a gRPC/websocket client and
/// a backend proxy to keep your service-account key off the device, so
/// it's a bigger lift than `speech_to_text` for the "live captions" UI
/// in the mockup. Reach for this when you need Google's language
/// coverage/accuracy and already have a backend to hold the API key.
///
/// Setup:
/// 1. Enable the "Cloud Speech-to-Text API" in Google Cloud Console.
/// 2. Create an API key (or better: proxy this call through your own
///    backend so the key never ships inside the app).
/// 3. Record audio client-side (e.g. with the `record` package) as
///    LINEAR16/FLAC, base64-encode it, and call [transcribeAudioBytes].
class GoogleSpeechService {
  GoogleSpeechService({required this.apiKey});

  final String apiKey;

  Future<String> transcribeAudioBytes(
    List<int> audioBytes, {
    String languageCode = 'en-US',
    String encoding = 'LINEAR16',
    int sampleRateHertz = 16000,
  }) async {
    final url = Uri.parse(
      'https://speech.googleapis.com/v1/speech:recognize?key=$apiKey',
    );

    final body = jsonEncode({
      'config': {
        'encoding': encoding,
        'sampleRateHertz': sampleRateHertz,
        'languageCode': languageCode,
      },
      'audio': {'content': base64Encode(audioBytes)},
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Google Speech-to-Text failed: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final results = decoded['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return '';

    final firstAlternative =
        (results.first['alternatives'] as List<dynamic>).first;
    return firstAlternative['transcript'] as String? ?? '';
  }

  /// Convenience overload if you already have an audio [File] on disk.
  Future<String> transcribeFile(File audioFile, {String languageCode = 'en-US'}) {
    final bytes = audioFile.readAsBytesSync();
    return transcribeAudioBytes(bytes, languageCode: languageCode);
  }
}
