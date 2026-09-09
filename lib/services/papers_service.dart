import 'dart:convert';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:shared_preferences/shared_preferences.dart';

class Paper {
  final String id;
  final String title;
  final String authors;
  final String category;
  final String year;
  final String status; // 'analyzed', 'reading', 'unread'
  final double? progress; // 0.0 to 1.0
  final String? summary;
  final DateTime dateAdded;
  bool isFavorite; // ← Changed from final to bool (mutable)

  Paper({
    required this.id,
    required this.title,
    required this.authors,
    required this.category,
    required this.year,
    required this.status,
    this.progress,
    this.summary,
    required this.dateAdded,
    this.isFavorite = false, // ← Now can be modified
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'authors': authors,
    'category': category,
    'year': year,
    'status': status,
    'progress': progress,
    'summary': summary,
    'dateAdded': dateAdded.toIso8601String(),
    'isFavorite': isFavorite,
  };

  factory Paper.fromJson(Map<String, dynamic> json) => Paper(
    id: json['id'],
    title: json['title'],
    authors: json['authors'],
    category: json['category'],
    year: json['year'],
    status: json['status'],
    progress: json['progress']?.toDouble(),
    summary: json['summary'],
    dateAdded: DateTime.parse(json['dateAdded']),
    isFavorite: json['isFavorite'] ?? false,
  );
}

class PapersService {
  static final PapersService _instance = PapersService._internal();
  factory PapersService() => _instance;
  PapersService._internal();

  List<Paper> _papers = [];
  bool _isInitialized = false;

  List<Paper> get papers => _papers;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadPapers();
    _isInitialized = true;
  }

  Future<void> _loadPapers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final papersJson = prefs.getString('saved_papers');
      if (papersJson != null) {
        final List<dynamic> decoded = jsonDecode(papersJson);
        _papers = decoded.map((e) => Paper.fromJson(e as Map<String, dynamic>)).toList();
        _sortPapers();
      } else {
        // Add sample papers
        _papers = [
          Paper(
            id: '1',
            title: 'The Impact of AI on Qualitative Research',
            authors: 'Smith, J., et al. Exploring the methodological shifts and ethical considerations in AI-assisted qualitative analysis.',
            category: 'QUALITATIVE METHODS',
            year: '2024',
            status: 'analyzed',
            summary: 'This paper explores the integration of AI tools in qualitative research methodologies.',
            dateAdded: DateTime.now().subtract(const Duration(days: 2)),
            isFavorite: false,
          ),
          Paper(
            id: '2',
            title: 'Foundations of Modern Pedagogy',
            authors: 'Johnson, M. A comprehensive review of evolving pedagogical approaches in higher education.',
            category: 'EDUCATION',
            year: '2023',
            status: 'reading',
            progress: 0.65,
            dateAdded: DateTime.now().subtract(const Duration(days: 5)),
            isFavorite: false,
          ),
          Paper(
            id: '3',
            title: 'Neural Networks for Beginners',
            authors: 'Lee, K., Patel, R. An accessible introduction to the underlying principles of neural networks.',
            category: 'COMPUTER SCIENCE',
            year: '2022',
            status: 'unread',
            dateAdded: DateTime.now().subtract(const Duration(days: 10)),
            isFavorite: false,
          ),
        ];
        await _savePapers();
      }
    } catch (e) {
      debugPrint('Error loading papers: $e');
    }
  }

  Future<void> _savePapers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final papersJson = jsonEncode(_papers.map((e) => e.toJson()).toList());
      await prefs.setString('saved_papers', papersJson);
    } catch (e) {
      debugPrint('Error saving papers: $e');
    }
  }

  void _sortPapers() {
    _papers.sort((a, b) {
      // Pinned/favorite notes first
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      // Then by date added (newest first)
      return b.dateAdded.compareTo(a.dateAdded);
    });
  }

  Future<void> addPaper(Paper paper) async {
    _papers.insert(0, paper);
    _sortPapers();
    await _savePapers();
  }

  Future<void> updatePaper(Paper paper) async {
    final index = _papers.indexWhere((p) => p.id == paper.id);
    if (index != -1) {
      _papers[index] = paper;
      _sortPapers();
      await _savePapers();
    }
  }

  Future<void> deletePaper(String id) async {
    _papers.removeWhere((p) => p.id == id);
    await _savePapers();
  }

  Future<void> toggleFavorite(String id) async {
    final index = _papers.indexWhere((p) => p.id == id);
    if (index != -1) {
      // Now we can modify isFavorite because it's not final
      _papers[index].isFavorite = !_papers[index].isFavorite;
      _sortPapers();
      await _savePapers();
    }
  }

  List<Paper> getPapersByStatus(String status) {
    if (status == 'All') return _papers;
    return _papers.where((p) => p.status == status.toLowerCase()).toList();
  }

  List<Paper> searchPapers(String query) {
    if (query.isEmpty) return _papers;
    return _papers.where((paper) =>
      paper.title.toLowerCase().contains(query.toLowerCase()) ||
      paper.authors.toLowerCase().contains(query.toLowerCase()) ||
      paper.category.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  Map<String, int> getStatusCounts() {
    return {
      'All': _papers.length,
      'Analyzed': _papers.where((p) => p.status == 'analyzed').length,
      'Reading': _papers.where((p) => p.status == 'reading').length,
      'Unread': _papers.where((p) => p.status == 'unread').length,
    };
  }
}