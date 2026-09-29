import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;

// ==================== MODELS ====================

class SearchQuery {
  final String topic;
  List<String> keywords;
  final List<String> synonyms;
  final String booleanQuery;
  final String dateRange;
  final String discipline;

  SearchQuery({
    required this.topic,
    required this.keywords,
    required this.synonyms,
    required this.booleanQuery,
    required this.dateRange,
    required this.discipline,
  });

  factory SearchQuery.fromJson(String topic, Map<String, dynamic> json) {
    return SearchQuery(
      topic: topic,
      keywords: List<String>.from(json['keywords'] ?? []),
      synonyms: List<String>.from(json['synonyms'] ?? []),
      booleanQuery: json['boolean_query'] ?? '',
      dateRange: json['date_range'] ?? '2015-2025',
      discipline: json['discipline'] ?? 'All',
    );
  }
}

class SearchResult {
  final String id;
  final String title;
  final String authors;
  final String year;
  final String journal;
  final String abstract;
  final String source;
  final int citations;
  final String url;
  String aiSummary;
  final String aiMatchReason;

  SearchResult({
    required this.id,
    required this.title,
    required this.authors,
    required this.year,
    required this.journal,
    required this.abstract,
    required this.source,
    required this.citations,
    required this.url,
    this.aiSummary = '',
    this.aiMatchReason = '',
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      id: (json['id'] ?? '').toString(),
      title: json['title'] ?? 'Untitled',
      authors: json['authors'] ?? 'Unknown',
      year: json['year']?.toString() ?? 'N/A',
      journal: json['venue'] ?? json['journal'] ?? '',   // ← backend uses 'venue'
      abstract: json['abstract'] ?? '',
      source: json['source'] ?? 'Unknown',
      citations: json['citations'] ?? 0,
      url: json['url'] ?? '',
      aiSummary: json['ai_summary'] ?? '',
      aiMatchReason: json['ai_match_reason'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'authors': authors,
        'year': year,
        'journal': journal,
        'abstract': abstract,
        'source': source,
        'citations': citations,
        'url': url,
        'ai_summary': aiSummary,
      };
}

// ==================== SERVICE ====================

class SearchService {
  static final SearchService instance = SearchService._internal();
  SearchService._internal();

  // ⚠️ Backend URL
  // Android emulator: 10.0.2.2 points to host PC
  // iOS simulator: localhost
  // Real device: use PC LAN IP (e.g., 192.168.1.42)
  static String get _baseUrl {
  // Web (Chrome, Edge) — localhost works
  if (kIsWeb) return 'http://localhost:8000';

  // Android emulator — 10.0.2.2 maps to host PC's localhost
  if (Platform.isAndroid) return 'http://10.0.2.2:8000';

  // iOS simulator, macOS, Windows desktop — localhost
  return 'http://localhost:8000';
}

  /// Step 1: AI extracts keywords + boolean query from the topic
  Future<SearchQuery?> buildSearchQuery(String topic) async {
    if (topic.trim().isEmpty) return null;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/ai/build-search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'topic': topic}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return SearchQuery.fromJson(topic, data);
      }
      debugPrint('buildSearchQuery failed: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      debugPrint('buildSearchQuery error: $e');
      return null;
    }
  }

  /// Step 2: Search Semantic Scholar + AI summaries
  /// Backend returns: { "results": [...], "count": N }
  Future<List<SearchResult>> searchPapers({
    required String query,
    String dateRange = '2015-2025',
    String discipline = 'All',
    int limit = 20,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': query,
          'date_range': dateRange,
          'discipline': discipline,
          'limit': limit,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> results = data['results'] ?? [];
        return results.map((e) => SearchResult.fromJson(e)).toList();
      }

      if (response.statusCode == 429) {
        throw Exception('Rate limit — please wait a minute and try again');
      }
      throw Exception('Search failed: ${response.statusCode}');
    } catch (e) {
      debugPrint('searchPapers error: $e');
      rethrow;
    }
  }

  /// Save a paper to user's library
  Future<bool> savePaper(SearchResult paper) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/papers/save?user_id=test-user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(paper.toJson()),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('savePaper error: $e');
      return false;
    }
  }
}