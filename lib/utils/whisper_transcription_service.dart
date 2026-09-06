import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class WhisperTranscriptionService {
  final String apiKey;

  WhisperTranscriptionService({required this.apiKey});

  Future<String> transcribeFile(File audioFile) async {
    final uri = Uri.parse('https://api.openai.com/v1/audio/transcriptions');

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..fields['model'] = 'whisper-1'
      ..fields['language'] = 'en'
      ..files.add(await http.MultipartFile.fromPath('file', audioFile.path));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = jsonDecode(body);
      return data['text'] ?? '';
    } else {
      throw Exception('Whisper error: ${response.statusCode} - $body');
    }
  }
}