import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/app_constants.dart';

class PlagiarismMatch {
  final String id;
  final String text;
  final int similarityPercentage;
  final String sourceTitle;
  final String sourceAuthor;
  final String sourceYear;
  final String citationString;

  PlagiarismMatch({
    required this.id,
    required this.text,
    required this.similarityPercentage,
    required this.sourceTitle,
    required this.sourceAuthor,
    required this.sourceYear,
    required this.citationString,
  });

  // Backward compatibility getters
  String get source => sourceTitle;
  String get authors => sourceAuthor;
  String get year => sourceYear;
  String get percentage => '$similarityPercentage%';

  factory PlagiarismMatch.fromJson(Map<String, dynamic> json) => PlagiarismMatch(
    id: json['id']?.toString() ?? '',
    text: json['text'] ?? '',
    similarityPercentage: json['similarity_percentage'] is int
        ? json['similarity_percentage']
        : int.tryParse(json['similarity_percentage']?.toString().replaceAll('%', '') ?? '0') ??
            int.tryParse(json['percentage']?.toString().replaceAll('%', '') ?? '0') ?? 0,
    sourceTitle: json['source_title'] ?? json['source'] ?? '',
    sourceAuthor: json['source_author'] ?? json['authors'] ?? '',
    sourceYear: json['source_year']?.toString() ?? json['year']?.toString() ?? '',
    citationString: json['citation_string'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'text': text,
    'similarity_percentage': similarityPercentage,
    'source_title': sourceTitle,
    'source_author': sourceAuthor,
    'source_year': sourceYear,
    'citation_string': citationString,
  };
}

class PlagiarismResult {
  final String id;
  final int similarityScore;
  final int aiLikelihoodScore;
  final String aiLikelihoodExplanation;
  final List<PlagiarismMatch> matches;

  PlagiarismResult({
    required this.id,
    required this.similarityScore,
    required this.aiLikelihoodScore,
    required this.aiLikelihoodExplanation,
    required this.matches,
  });

  factory PlagiarismResult.fromJson(Map<String, dynamic> json) =>
      PlagiarismResult(
        id: json['id']?.toString() ?? '',
        similarityScore: json['similarity_score'] is int
            ? json['similarity_score']
            : int.tryParse(json['similarity_score']?.toString().replaceAll('%', '') ?? '0') ?? 0,
        aiLikelihoodScore: json['ai_likelihood_score'] is int
            ? json['ai_likelihood_score']
            : int.tryParse(json['ai_likelihood_score']?.toString().replaceAll('%', '') ?? '0') ?? 0,
        aiLikelihoodExplanation: json['ai_likelihood_explanation'] ?? '',
        matches: (json['matches'] as List? ?? [])
            .map((m) => PlagiarismMatch.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}

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