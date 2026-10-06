import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/app_constants.dart';

// ============================================================
// Models
// ============================================================
class PlagiarismMatch {
  final int id;
  final String text;
  final String percentage;
  final int words;
  final String source;
  final String year;
  final String excerpt;

  PlagiarismMatch({
    required this.id,
    required this.text,
    required this.percentage,
    required this.words,
    required this.source,
    required this.year,
    required this.excerpt,
  });

  factory PlagiarismMatch.fromJson(Map<String, dynamic> json) => PlagiarismMatch(
        id: json['id'] ?? 0,
        text: json['text'] ?? '',
        percentage: json['percentage'] ?? '0%',
        words: json['words'] ?? 0,
        source: json['source'] ?? '',
        year: json['year'] ?? '',
        excerpt: json['excerpt'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'percentage': percentage,
        'words': words,
        'source': source,
        'year': year,
        'excerpt': excerpt,
      };
}

class PlagiarismResult {
  final String id;
  final String similarityScore;
  final List<PlagiarismMatch> matches;

  PlagiarismResult({
    required this.id,
    required this.similarityScore,
    required this.matches,
  });

  factory PlagiarismResult.fromJson(Map<String, dynamic> json) =>
      PlagiarismResult(
        id: json['id'].toString(),
        similarityScore: json['similarity_score'] ?? '0%',
        matches: (json['matches'] as List? ?? [])
            .map((m) => PlagiarismMatch.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}

// ============================================================
// Service
// ============================================================
class PlagiarismService {
  static final PlagiarismService _instance = PlagiarismService._internal();
  factory PlagiarismService() => _instance;
  PlagiarismService._internal();

  String get _baseUrl => AppConstants.researchBaseUrl;

  Future<PlagiarismResult> check(String text) async {
    final r = await http.post(
      Uri.parse('$_baseUrl/plagiarism/check'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text, 'user_id': null}),
    );
    if (r.statusCode != 200) {
      throw Exception('Check failed: ${r.statusCode} — ${r.body}');
    }
    return PlagiarismResult.fromJson(jsonDecode(r.body));
  }

  Future<String> paraphrase(String text) async {
    final r = await http.post(
      Uri.parse('$_baseUrl/plagiarism/paraphrase'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text, 'mode': 'paraphrase'}),
    );
    if (r.statusCode != 200) {
      throw Exception('Paraphrase failed: ${r.statusCode}');
    }
    return (jsonDecode(r.body) as Map<String, dynamic>)['result'] as String;
  }

  Future<String> humanize(String text) async {
    final r = await http.post(
      Uri.parse('$_baseUrl/plagiarism/humanize'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text, 'mode': 'humanize'}),
    );
    if (r.statusCode != 200) {
      throw Exception('Humanize failed: ${r.statusCode}');
    }
    return (jsonDecode(r.body) as Map<String, dynamic>)['result'] as String;
  }

  Future<String> cite(String source, String year) async {
    final r = await http.post(
      Uri.parse('$_baseUrl/plagiarism/cite'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'source': source,
        'year': year,
        'style': 'APA 7',
      }),
    );
    if (r.statusCode != 200) {
      throw Exception('Citation failed: ${r.statusCode}');
    }
    return (jsonDecode(r.body) as Map<String, dynamic>)['citation'] as String;
  }
}