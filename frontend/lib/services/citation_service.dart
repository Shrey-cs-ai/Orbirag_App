import 'dart:convert';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/citation.dart';

class CitationService {
  static final CitationService instance = CitationService._internal();
  CitationService._internal();

  // ============================================================
  // Backend URL (research backend on 8001)
  // ============================================================
  String get baseUrl {
    if (kIsWeb) return 'http://localhost:8001';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8001';
    }
    return 'http://localhost:8001';
  }

  // ============================================================
  // In-memory + SharedPreferences cache
  // ============================================================
  List<Citation> _citations = [];
  bool _isInitialized = false;

  List<Citation> get citations => List.unmodifiable(_citations);
  int get citationsCount => _citations.length;

  // ============================================================
  // Initialize — load from local cache, then refresh from backend
  // ============================================================
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadFromPrefs();
    _isInitialized = true;
    // Fire-and-forget backend sync
    listCitations();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('saved_citations');
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _citations = list
            .map((e) => Citation.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[Citation] _loadFromPrefs error: $e');
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_citations.map((c) => {
            'id': c.id,
            'title': c.title,
            'authors': c.authors,
            'year': c.year,
            'journal': c.journal,
            'source_type': c.sourceType,
            'style': c.style,
            'in_text': c.inTextCitation,
            'reference_list': c.referenceList,
            'saved_at': c.savedAt.toIso8601String(),
          }).toList());
      await prefs.setString('saved_citations', raw);
    } catch (e) {
      debugPrint('[Citation] _saveToPrefs error: $e');
    }
  }

  // ============================================================
  // SAVE — POST backend + local cache
  // ============================================================
  Future<bool> saveCitation(Citation citation) async {
    // 1. Add locally first (UI feedback is instant)
    _citations.insert(0, citation);
    await _saveToPrefs();

    // 2. Send to backend
    try {
      debugPrint('[Citation] POST $baseUrl/api/citations/save');

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/citations/save?user_id=anonymous'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(citation.toJson()),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('[Citation] save status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[Citation] saveCitation exception: $e');
      return false;
    }
  }

  // ============================================================
  // LIST — GET backend
  // ============================================================
  Future<List<Citation>> listCitations() async {
    try {
      debugPrint('[Citation] GET $baseUrl/api/citations');

      final response = await http
          .get(
            Uri.parse('$baseUrl/api/citations?user_id=anonymous'),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (data['citations'] ?? []) as List;

        _citations = list
            .map((c) => Citation.fromJson(c as Map<String, dynamic>))
            .toList();
        await _saveToPrefs();
        return _citations;
      }
      return _citations; // fallback to local cache
    } catch (e) {
      debugPrint('[Citation] listCitations exception: $e');
      return _citations;
    }
  }

  // ============================================================
  // DELETE — backend + local
  // ============================================================
  Future<bool> deleteCitation(String id) async {
    // Local first
    _citations.removeWhere((c) => c.id == id);
    await _saveToPrefs();

    // Then backend
    try {
      debugPrint('[Citation] DELETE $baseUrl/api/citations/$id');

      final response = await http
          .delete(
            Uri.parse('$baseUrl/api/citations/$id?user_id=anonymous'),
          )
          .timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[Citation] deleteCitation exception: $e');
      return false;
    }
  }

  // ============================================================
  // Clear all (local)
  // ============================================================
  Future<void> clearAll() async {
    _citations.clear();
    await _saveToPrefs();
  }

  // ============================================================
  // Search
  // ============================================================
  List<Citation> searchCitations(String query) {
    if (query.isEmpty) return _citations;
    final q = query.toLowerCase();
    return _citations
        .where((c) =>
            c.title.toLowerCase().contains(q) ||
            c.authors.toLowerCase().contains(q) ||
            c.journal.toLowerCase().contains(q))
        .toList();
  }

  // ============================================================
  // Quick helpers (used by Plagiarism screen)
  // ============================================================
  String quickInTextFromSource(String source, {String year = "2024"}) {
    if (source.trim().isEmpty) return "($year)";
    String authorPart = source;
    if (source.contains(',')) {
      authorPart = source.split(',').first.trim();
    }
    if (authorPart.split(' ').length > 3) {
      authorPart = authorPart.split(' ').take(2).join(' ');
    }
    return "($authorPart, $year)";
  }

  String quickReferenceFromSource({
    required String source,
    required String year,
    String? journal,
  }) {
    final buffer = StringBuffer();
    buffer.write(source);
    buffer.write(' ($year). ');
    if (journal != null && journal.isNotEmpty) {
      buffer.write(journal);
      buffer.write('.');
    }
    return buffer.toString();
  }

  void clearCache() {
    _citations.clear();
    _saveToPrefs();
  }
}