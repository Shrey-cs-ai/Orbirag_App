import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class WhisperTranscriptionService {
  WhisperTranscriptionService({required this.apiKey});
  
  final String apiKey;
  static const String _endpoint = 'https://api.openai.com/v1/audio/transcriptions';

  /// Transcribe audio file using Whisper API
  Future<String> transcribeFile(File audioFile, {String model = 'whisper-1'}) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_endpoint))
        ..headers['Authorization'] = 'Bearer $apiKey'
        ..fields['model'] = model
        ..fields['language'] = 'en'
        ..files.add(await http.MultipartFile.fromPath('file', audioFile.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('Whisper API error: ${response.statusCode} - ${response.body}');
      }

      final body = jsonDecode(response.body);
      return body['text']?.toString()?.trim() ?? '';
    } catch (e) {
      throw Exception('Transcription failed: $e');
    }
  }

  /// Alternative: Transcribe with custom configuration
  Future<String> transcribeWithConfig(
    File audioFile, {
    String model = 'whisper-1',
    String language = 'en',
    String? prompt,
    double temperature = 0.0,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_endpoint))
        ..headers['Authorization'] = 'Bearer $apiKey'
        ..fields['model'] = model
        ..fields['language'] = language
        ..fields['temperature'] = temperature.toString()
        ..files.add(await http.MultipartFile.fromPath('file', audioFile.path));

      if (prompt != null) {
        request.fields['prompt'] = prompt;
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('Whisper API error: ${response.statusCode}');
      }

      final body = jsonDecode(response.body);
      return body['text']?.toString()?.trim() ?? '';
    } catch (e) {
      throw Exception('Transcription failed: $e');
    }
  }
}