import 'dart:convert';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:http/http.dart' as http;
import 'papers_service.dart';

class SearchService {
  static final SearchService instance = SearchService._internal();
  SearchService._internal();

  // ============================================================
  // ✅ Research backend runs on port 8001
  // ============================================================
  String get baseUrl {
    if (kIsWeb) return 'http://localhost:8001';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8001';
    }
    return 'http://localhost:8001';
  }

  // ============================================================
  // 1. Build Query → keywords + synonyms + boolean_query
  // ============================================================
  Future<SearchQuery?> buildSearchQuery(String topic) async {
    try {
      debugPrint('[Search] POST $baseUrl/api/ai/build-search');

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/ai/build-search'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'topic': topic}),
          )
          .timeout(const Duration(seconds: 45));

      debugPrint('[Search] build-search status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return SearchQuery(
          keywords: List<String>.from(data['keywords'] ?? []),
          synonyms: List<String>.from(data['synonyms'] ?? []),
          booleanQuery: (data['boolean_query'] ?? '') as String,
        );
      }
      debugPrint('[Search] build-search error body: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[Search] buildSearchQuery exception: $e');
      return null;
    }
  }

  // ============================================================
  // 2. Search Papers → List<SearchResult>
  // ============================================================
  Future<List<SearchResult>> searchPapers({
    required String query,
    String? dateRange,
    String? discipline,
    int limit = 10,
  }) async {
    try {
      debugPrint('[Search] POST $baseUrl/api/search');

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/search'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'query': query,
              'limit': limit,
              'date_range': dateRange,
              'discipline': discipline,
            }),
          )
          .timeout(const Duration(seconds: 90));

      debugPrint('[Search] /api/search status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (data['results'] ?? []) as List;
        return list
            .map((p) => SearchResult.fromJson(p as Map<String, dynamic>))
            .toList();
      }
      debugPrint('[Search] search error body: ${response.body}');
      return [];
    } catch (e) {
      debugPrint('[Search] searchPapers exception: $e');
      return [];
    }
  }

  // ============================================================
  // 3. Save Paper → bool
  // ============================================================
  Future<bool> savePaper(SearchResult paper) async {
    final payload = {
      'title': paper.title,
      'authors': paper.authors,
      'year': paper.year,
      'source': paper.source,
      'citations': paper.citations,
      'ai_summary': paper.aiSummary,
      'url': paper.url,
      'abstract': paper.abstract,
      'venue': paper.venue,
    };
    try {
      debugPrint('[Search] POST $baseUrl/api/save-paper');

      await PapersService().initialize();
      await PapersService().addPaper(
        Paper(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: paper.title,
          url: paper.url.isNotEmpty ? paper.url : null,
          authors: paper.authors,
          category: paper.venue.isNotEmpty ? paper.venue : 'GENERAL',
          year: paper.year.isNotEmpty ? paper.year : '2024',
          status: 'unread',
          summary: paper.aiSummary,
          dateAdded: DateTime.now(),
        ),
      );

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/save-paper'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('[Search] save-paper status: ${response.statusCode}');
      if (response.statusCode == 422) {
        debugPrint('[Search] 422 Unprocessable Entity! Payload sent: ${jsonEncode(payload)}');
        debugPrint('[Search] Backend expected schema: SavePaperRequest(title, authors, year, source, citations, ai_summary, url, abstract, venue)');
        debugPrint('[Search] Backend response: ${response.body}');
      }
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[Search] savePaper exception: $e');
      return false;
    }
  }
}

// ============================================================
// MODELS
// ============================================================
class SearchQuery {
  final List<String> keywords;
  final List<String> synonyms;
  final String booleanQuery;

  SearchQuery({
    required this.keywords,
    required this.synonyms,
    required this.booleanQuery,
  });
}

class SearchResult {
  final String title;
  final String authors;
  final String year;
  final String source;
  final int citations;
  final String aiSummary;
  final String url;
  final String abstract;
  final String venue;

  SearchResult({
    required this.title,
    required this.authors,
    required this.year,
    required this.source,
    required this.citations,
    required this.aiSummary,
    this.url = '',
    this.abstract = '',
    this.venue = '',
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      title: (json['title'] ?? 'Untitled') as String,
      authors: (json['authors'] ?? 'Unknown authors') as String,
      year: json['year']?.toString() ?? '',
      source: (json['source'] ?? 'Semantic Scholar') as String,
      citations: (json['citations'] ?? 0) as int,
      // ⚠️ Backend uses snake_case — match it
      aiSummary: (json['ai_summary'] ?? '') as String,
      url: (json['url'] ?? '') as String,
      abstract: (json['abstract'] ?? '') as String,
      venue: (json['venue'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'authors': authors,
        'year': year,
        'source': source,
        'citations': citations,
        'ai_summary': aiSummary,
        'url': url,
        'abstract': abstract,
        'venue': venue,
      };
}