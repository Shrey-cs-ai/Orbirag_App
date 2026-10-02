import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/analysis_result.dart';
import '../utils/app_constants.dart';

class WordCounterApi {
  final String baseUrl;

  WordCounterApi({String? baseUrl}) : baseUrl = baseUrl ?? AppConstants.apiBaseUrl;

  Future<AnalysisResult> analyze({
    required String text,
    List<String> ignoreWords = const [],
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/analyze'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'text': text,
        'ignore_words': ignoreWords,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to analyze text: ${response.statusCode}');
    }

    final json = jsonDecode(response.body);
    return AnalysisResult.fromJson(json);
  }
}