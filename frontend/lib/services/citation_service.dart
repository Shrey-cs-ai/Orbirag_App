import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==================== CITATION MODEL ====================
// This fixes the "method 'Citation' isn't defined" error
class Citation {
  final String id;
  final String title;
  final String authors;
  final String year;
  final String journal;
  final String sourceType;
  final String style;
  final String inTextCitation;
  final String referenceList;
  final DateTime savedAt;

  Citation({
    required this.id,
    required this.title,
    required this.authors,
    required this.year,
    required this.journal,
    required this.sourceType,
    required this.style,
    required this.inTextCitation,
    required this.referenceList,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'authors': authors,
    'year': year,
    'journal': journal,
    'sourceType': sourceType,
    'style': style,
    'inTextCitation': inTextCitation,
    'referenceList': referenceList,
    'savedAt': savedAt.toIso8601String(),
  };

  factory Citation.fromJson(Map<String, dynamic> json) => Citation(
    id: json['id'],
    title: json['title'],
    authors: json['authors'],
    year: json['year'],
    journal: json['journal'],
    sourceType: json['sourceType'],
    style: json['style'],
    inTextCitation: json['inTextCitation'],
    referenceList: json['referenceList'],
    savedAt: DateTime.parse(json['savedAt']),
  );
}

// ==================== CITATION SERVICE ====================
class CitationService {
  // Singleton instance (Used in your screens)
  static final CitationService instance = CitationService._internal();
  CitationService._internal();

  List<Citation> _citations = [];
  bool _isInitialized = false;

  List<Citation> get citations => _citations;
  int get citationsCount => _citations.length;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadCitations();
    _isInitialized = true;
  }

  Future<void> _loadCitations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final citationsJson = prefs.getString('saved_citations');
      if (citationsJson != null) {
        final List<dynamic> decoded = jsonDecode(citationsJson);
        _citations = decoded
            .map((e) => Citation.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading citations: $e');
    }
  }

  Future<void> _saveCitations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final citationsJson =
          jsonEncode(_citations.map((e) => e.toJson()).toList());
      await prefs.setString('saved_citations', citationsJson);
    } catch (e) {
      debugPrint('Error saving citations: $e');
    }
  }

  // ==================== SAVE CITATION ====================
  // This fixes the "method 'saveCitation' isn't defined" error
  Future<void> saveCitation(Citation citation) async {
    _citations.insert(0, citation);
    await _saveCitations();
  }

  Future<void> deleteCitation(String id) async {
    _citations.removeWhere((c) => c.id == id);
    await _saveCitations();
  }

  Future<void> clearAll() async {
    _citations.clear();
    await _saveCitations();
  }

  List<Citation> searchCitations(String query) {
    if (query.isEmpty) return _citations;
    return _citations
        .where((c) =>
            c.title.toLowerCase().contains(query.toLowerCase()) ||
            c.authors.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  // ==================== QUICK CITATIONS (Used by Plagiarism Screen) ====================
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
}