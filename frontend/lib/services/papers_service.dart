import 'dart:convert';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:http/http.dart' as http;

// ============================================================
// Model
// ============================================================
class Paper {
  final String id;
  final String title;
  final String authors;
  final String category; // maps to journal/source from backend
  final String year;
  final String status; // unread | reading | analyzed | read
  final double progress;
  final String? url;
  final String? abstract;
  final String? summary;
  final bool isFavorite;

  Paper({
    required this.id,
    required this.title,
    required this.authors,
    required this.category,
    required this.year,
    required this.status,
    this.progress = 0.0,
    this.url,
    this.abstract,
    this.summary,
    this.isFavorite = false,
  });

  Paper copyWith({
    String? status,
    double? progress,
    bool? isFavorite,
  }) =>
      Paper(
        id: id,
        title: title,
        authors: authors,
        category: category,
        year: year,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        url: url,
        abstract: abstract,
        summary: summary,
        isFavorite: isFavorite ?? this.isFavorite,
      );

  factory Paper.fromJson(Map<String, dynamic> j) => Paper(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? 'Untitled').toString(),
        authors: (j['authors'] ?? '').toString(),
        category: ((j['journal'] ?? j['source'] ?? 'General')).toString(),
        year: (j['year'] ?? '').toString(),
        status: (j['status'] ?? 'unread').toString(),
        progress: ((j['progress'] ?? 0.0) as num).toDouble(),
        url: j['url']?.toString(),
        abstract: j['abstract']?.toString(),
        isFavorite: j['is_favorite'] == true,
      );
}

// ============================================================
// Service
// ============================================================
class PapersService {
  static final PapersService _instance = PapersService._internal();
  factory PapersService() => _instance;
  PapersService._internal();

  List<Paper> _papers = [];
  bool _isInitialized = false;

  List<Paper> get papers => List.unmodifiable(_papers);

  String get baseUrl {
    if (kIsWeb) return 'http://localhost:8001';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8001';
    }
    return 'http://localhost:8001';
  }

  // ── Load from backend ───────────────────────────────────
  Future<void> initialize() async {
    // Always refresh — data lives on the server
    await _fetchPapers();
    _isInitialized = true;
  }

  Future<void> _fetchPapers() async {
    try {
      final r = await http
          .get(Uri.parse('$baseUrl/api/papers?user_id=anonymous'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        final list = (data['items'] ?? []) as List;
        _papers = list
            .map((e) => Paper.fromJson(e as Map<String, dynamic>))
            .toList();
        _sortPapers();
      } else {
        debugPrint('[Papers] fetch error ${r.statusCode}: ${r.body}');
      }
    } catch (e) {
      debugPrint('[Papers] fetch exception: $e');
    }
  }

  void _sortPapers() {
    _papers.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      return 0;
    });
  }

  // ── Reload (call after any mutation) ───────────────────
  Future<void> reload() async {
    await _fetchPapers();
  }

  // ── Add (called by saved_papers_screen Add Paper dialog) ──
  Future<void> addPaper(Paper paper) async {
    // For manually-added papers we call the save-paper endpoint
    try {
      final payload = {
        'title': paper.title,
        'authors': paper.authors,
        'year': paper.year,
        'venue': paper.category,
        'source': 'Manual',
        'citations': 0,
        'ai_summary': paper.summary ?? '',
        'url': paper.url ?? '',
        'abstract': paper.abstract ?? '',
      };
      await http
          .post(
            Uri.parse('$baseUrl/api/save-paper'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[Papers] addPaper exception: $e');
    }
    await reload();
  }

  // ── Delete ─────────────────────────────────────────────
  Future<void> deletePaper(String id) async {
    try {
      await http
          .delete(Uri.parse('$baseUrl/api/papers/$id'))
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[Papers] deletePaper exception: $e');
    }
    _papers.removeWhere((p) => p.id == id);
  }

  // ── Toggle favourite (local only — no backend endpoint yet) ─
  Future<void> toggleFavorite(String id) async {
    final idx = _papers.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _papers[idx] = _papers[idx].copyWith(isFavorite: !_papers[idx].isFavorite);
      _sortPapers();
    }
  }

  // ── Update progress ────────────────────────────────────
  Future<void> updateProgress({
    required String id,
    required String status,
    required double progress,
  }) async {
    try {
      await http
          .patch(
            Uri.parse('$baseUrl/api/papers/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'status': status, 'progress': progress}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[Papers] updateProgress exception: $e');
    }
    // Update in-memory copy
    final idx = _papers.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _papers[idx] = _papers[idx].copyWith(status: status, progress: progress);
    }
  }

  // ── Filter helpers ─────────────────────────────────────
  List<Paper> getPapersByStatus(String status) {
    if (status == 'All') return _papers;
    return _papers.where((p) => p.status == status.toLowerCase()).toList();
  }

  List<Paper> searchPapers(String query) {
    if (query.isEmpty) return _papers;
    final q = query.toLowerCase();
    return _papers
        .where((p) =>
            p.title.toLowerCase().contains(q) ||
            p.authors.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q))
        .toList();
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