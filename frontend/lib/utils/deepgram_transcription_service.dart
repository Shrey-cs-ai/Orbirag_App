import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class DeepgramTranscriptionService {
  final String apiKey;

  DeepgramTranscriptionService({required this.apiKey});

  Future<String> transcribeFile(File audioFile) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('Deepgram API key is not configured.');
    }

    final response = await http.post(
      Uri.parse(
        'https://api.deepgram.com/v1/listen'
        '?model=nova-3&smart_format=true&language=en-US',
      ),
      headers: {
        'Authorization': 'Token ${apiKey.trim()}',
        'Content-Type': 'audio/mp4',
      },
      body: await audioFile.readAsBytes(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Deepgram error: ${response.statusCode} - ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as Map<String, dynamic>?;
    final channels = results?['channels'] as List<dynamic>?;
    final firstChannel = channels?.isNotEmpty == true
        ? channels!.first as Map<String, dynamic>
        : null;
    final alternatives = firstChannel?['alternatives'] as List<dynamic>?;
    final firstAlternative = alternatives?.isNotEmpty == true
        ? alternatives!.first as Map<String, dynamic>
        : null;

    return firstAlternative?['transcript'] as String? ?? '';
  }
}