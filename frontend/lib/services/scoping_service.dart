import 'dart:convert';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:http/http.dart' as http;

// ============================================================
// Model
// ============================================================
class ScopingData {
  String topic;
  String population;
  String intervention;
  String comparison;
  String outcome;
  String researchQuestion;

  ScopingData({
    this.topic = '',
    this.population = '',
    this.intervention = '',
    this.comparison = '',
    this.outcome = '',
    this.researchQuestion = '',
  });

  factory ScopingData.fromJson(Map<String, dynamic> j) => ScopingData(
        topic: (j['topic'] ?? '').toString(),
        population: (j['population'] ?? '').toString(),
        intervention: (j['intervention'] ?? '').toString(),
        comparison: (j['comparison'] ?? '').toString(),
        outcome: (j['outcome'] ?? '').toString(),
        researchQuestion: (j['research_question'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'topic': topic,
        'population': population,
        'intervention': intervention,
        'comparison': comparison,
        'outcome': outcome,
        'research_question': researchQuestion,
      };
}

// ============================================================
// Service
// ============================================================
class ScopingService {
  static final ScopingService instance = ScopingService._internal();
  factory ScopingService() => instance;
  ScopingService._internal();

  String get baseUrl {
    if (kIsWeb) return 'http://localhost:8001';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8001';
    }
    return 'http://localhost:8001';
  }

  Future<ScopingData?> parseTopic(String topic) async {
    try {
      final r = await http
          .post(
            Uri.parse('$baseUrl/api/scoping/parse'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'topic': topic}),
          )
          .timeout(const Duration(seconds: 30));

      if (r.statusCode != 200) {
        debugPrint('[Scoping] parse failed: ${r.statusCode} ${r.body}');
        return null;
      }
      return ScopingData.fromJson(jsonDecode(r.body));
    } catch (e) {
      debugPrint('[Scoping] parse exception: $e');
      return null;
    }
  }

  Future<String?> synthesizeQuestion(ScopingData data, {bool regenerate = false}) async {
    try {
      final payload = {
        ...data.toJson(),
        'regenerate': regenerate,
        'nonce': DateTime.now().millisecondsSinceEpoch,
      };
      final r = await http
          .post(
            Uri.parse('$baseUrl/api/scoping/synthesize'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (r.statusCode != 200) {
        debugPrint('[Scoping] synthesize failed: ${r.statusCode} ${r.body}');
        return null;
      }
      final json = jsonDecode(r.body) as Map<String, dynamic>;
      return (json['research_question'] ?? '').toString();
    } catch (e) {
      debugPrint('[Scoping] synthesize exception: $e');
      return null;
    }
  }

  Future<bool> saveSession(ScopingData data) async {
    try {
      final r = await http
          .post(
            Uri.parse('$baseUrl/api/scoping/sessions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({...data.toJson(), 'user_id': 'anonymous'}),
          )
          .timeout(const Duration(seconds: 30));

      return r.statusCode == 200 || r.statusCode == 201;
    } catch (e) {
      debugPrint('[Scoping] save exception: $e');
      return false;
    }
  }

  Future<List<ScopingData>> listSessions() async {
    try {
      final r = await http
          .get(Uri.parse('$baseUrl/api/scoping/sessions?user_id=anonymous'))
          .timeout(const Duration(seconds: 30));
      if (r.statusCode != 200) return [];
      final json = jsonDecode(r.body) as Map<String, dynamic>;
      final items = (json['items'] as List? ?? []);
      return items.map((e) => ScopingData.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[Scoping] list exception: $e');
      return [];
    }
  }
}