import 'dart:convert';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:http/http.dart' as http;

class PlagiarismService {
  static final PlagiarismService instance = PlagiarismService._internal();
  PlagiarismService._internal();

  // ============================================================
  // ✅ Research backend URL — port 8001
  // ============================================================
  String get baseUrl {
    if (kIsWeb) return 'http://localhost:8001';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8001';
    }
    return 'http://localhost:8001';
  }

  // ============================================================
  // 1. Run Plagiarism Check
  // ============================================================
  Future<PlagiarismResult?> check({
    required String text,
    double threshold = 0.75,
  }) async {
    try {
      debugPrint('[Plagiarism] POST $baseUrl/api/plagiarism/check');

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/plagiarism/check'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': text,
              'threshold': threshold,
            }),
          )
          .timeout(const Duration(seconds: 60));

      debugPrint('[Plagiarism] status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return PlagiarismResult.fromJson(data);
      }
      debugPrint('[Plagiarism] error body: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[Plagiarism] exception: $e');
      return null;
    }
  }

  // ============================================================
  // 2. Rewrite — paraphrase or humanize
  // ============================================================
  Future<String?> rewrite({
    required String text,
    required String mode, // "paraphrase" or "humanize"
  }) async {
    try {
      debugPrint('[Rewrite] POST $baseUrl/api/ai/rewrite (mode=$mode)');

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/ai/rewrite'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text, 'mode': mode}),
          )
          .timeout(const Duration(seconds: 60));

      debugPrint('[Rewrite] status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['result'] ?? '') as String;
      }
      debugPrint('[Rewrite] error body: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[Rewrite] exception: $e');
      return null;
    }
  }
}

// ============================================================
// MODELS
// ============================================================
class PlagiarismResult {
  final double score;
  final int totalWords;
  final int uniqueWords;
  final int flaggedCount;
  final List<PlagiarismMatch> matches;
  final String summary;

  PlagiarismResult({
    required this.score,
    required this.totalWords,
    required this.uniqueWords,
    required this.flaggedCount,
    required this.matches,
    required this.summary,
  });

  factory PlagiarismResult.fromJson(Map<String, dynamic> json) {
    return PlagiarismResult(
      score: ((json['score'] ?? 0) as num).toDouble(),
      totalWords: (json['total_words'] ?? 0) as int,
      uniqueWords: (json['unique_words'] ?? 0) as int,
      flaggedCount: (json['flagged_count'] ?? 0) as int,
      summary: (json['summary'] ?? '') as String,
      matches: ((json['matches'] ?? []) as List)
          .map((m) => PlagiarismMatch.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PlagiarismMatch {
  final String source;
  final String matchedText;
  final double similarity;
  final String reason;

  PlagiarismMatch({
    required this.source,
    required this.matchedText,
    required this.similarity,
    required this.reason,
  });

  factory PlagiarismMatch.fromJson(Map<String, dynamic> json) {
    return PlagiarismMatch(
      source: (json['source'] ?? 'Unknown') as String,
      matchedText: (json['matched_text'] ?? '') as String,
      similarity: ((json['similarity'] ?? 0) as num).toDouble(),
      reason: (json['reason'] ?? '') as String,
    );
  }
}