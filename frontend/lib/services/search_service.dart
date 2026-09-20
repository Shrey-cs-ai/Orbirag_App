import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ==================== MODELS ====================

/// Represents the AI-extracted search query (keywords, synonyms, boolean)
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

/// Represents a single academic paper result
class SearchResult {
  final String id;
  final String title;
  final String authors;
  final String year;
  final String journal;
  final String abstract;
  final String source; // PubMed, IEEE, arXiv
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
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled',
      authors: json['authors'] ?? 'Unknown',
      year: json['year']?.toString() ?? 'N/A',
      journal: json['journal'] ?? '',
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
      };
}

// ==================== SERVICE ====================

class SearchService {
  static final SearchService instance = SearchService._internal();
  SearchService._internal();

  // ⚠️ IMPORTANT: Change this to your backend URL
  // Android emulator: 'http://10.0.2.2:8000'
  // iOS simulator: 'http://localhost:8000'
  // Real device: 'http://<YOUR_PC_IP>:8000'
  static const String _baseUrl = 'http://10.0.2.2:8000';

  /// Step 1: Use AI to extract keywords, synonyms, and boolean query from user topic
  Future<SearchQuery?> buildSearchQuery(String topic) async {
    if (topic.trim().isEmpty) return null;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/ai/build-search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'topic': topic}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SearchQuery.fromJson(topic, data);
      }
      throw Exception('Failed: ${response.statusCode}');
    } catch (e) {
      debugPrint('Build query error: $e');
      return null;
    }
  }

  /// Step 2: Run semantic + vector search on the backend
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
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => SearchResult.fromJson(e)).toList();
      }
      throw Exception('Search failed: ${response.statusCode}');
    } catch (e) {
      debugPrint('Search error: $e');
      rethrow;
    }
  }

  /// Step 3: Batch summarize the results using AI
  Future<List<SearchResult>> summarizeResults(List<SearchResult> results) async {
    if (results.isEmpty) return results;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/ai/summarize-batch'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'papers': results
              .map((r) => {
                    'id': r.id,
                    'title': r.title,
                    'abstract': r.abstract,
                  })
              .toList(),
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> summaries = jsonDecode(response.body);
        for (var r in results) {
          final s = summaries[r.id];
          if (s != null) {
            r.aiSummary = s['summary'] ?? '';
          }
        }
      }
    } catch (e) {
      debugPrint('Summarize error: $e');
    }
    return results;
  }

  /// Step 4: Save a paper to user's library (PostgreSQL)
  Future<bool> savePaper(SearchResult paper) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/papers/save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(paper.toJson()),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Save error: $e');
      return false;
    }
  }
}