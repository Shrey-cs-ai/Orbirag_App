import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ==================== MODELS ====================

class ScopingData {
  String topic;
  String population;
  String intervention;
  String comparison;
  String outcome;
  String dateRange;
  String discipline;
  String language;
  bool peerReviewedOnly;
  String researchQuestion;

  ScopingData({
    this.topic = '',
    this.population = '',
    this.intervention = '',
    this.comparison = '',
    this.outcome = '',
    this.dateRange = '2015-2025',
    this.discipline = 'All',
    this.language = 'English',
    this.peerReviewedOnly = true,
    this.researchQuestion = '',
  });

  bool get isComplete =>
      population.isNotEmpty &&
      intervention.isNotEmpty &&
      outcome.isNotEmpty;
}

// ==================== SERVICE ====================

class ScopingService {
  static final ScopingService instance = ScopingService._internal();
  ScopingService._internal();

  static const String _baseUrl = 'http://10.0.2.2:8000';

  /// Step 1: Parse topic into PICO fields using AI
  Future<ScopingData?> parseTopic(String topic) async {
    if (topic.trim().isEmpty) return null;

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/ai/parse-topic'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'topic': topic}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ScopingData(
          topic: topic,
          population: data['population'] ?? '',
          intervention: data['intervention'] ?? '',
          comparison: data['comparison'] ?? '',
          outcome: data['outcome'] ?? '',
        );
      }
    } catch (e) {
      debugPrint('Parse error: $e');
    }
    return ScopingData(topic: topic);
  }

  /// Step 2: Get AI suggestions for a field
  Future<List<String>> getSuggestions({
    required String fieldName,
    required String fieldValue,
    required String topic,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/ai/suggest'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'field_name': fieldName,
              'field_value': fieldValue,
              'topic': topic,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['suggestions'] ?? []);
      }
    } catch (e) {
      debugPrint('Suggestions error: $e');
    }
    return [];
  }

  /// Step 3: Synthesize research question from PICO
  Future<String?> synthesizeQuestion(ScopingData data) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/ai/synthesize'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'population': data.population,
              'intervention': data.intervention,
              'comparison': data.comparison,
              'outcome': data.outcome,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['question'];
      }
    } catch (e) {
      debugPrint('Synthesis error: $e');
    }
    // Fallback: build manually
    return _buildFallbackQuestion(data);
  }

  String _buildFallbackQuestion(ScopingData data) {
    final buffer = StringBuffer('How does ');
    if (data.intervention.isNotEmpty) buffer.write(data.intervention);
    if (data.comparison.isNotEmpty) {
      buffer.write(' compared to ${data.comparison}');
    }
    if (data.outcome.isNotEmpty) buffer.write(' affect ${data.outcome}');
    if (data.population.isNotEmpty) {
      buffer.write(' in ${data.population}');
    }
    buffer.write('?');
    return buffer.toString();
  }
}