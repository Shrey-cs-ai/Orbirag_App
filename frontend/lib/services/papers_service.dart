// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ──────────────────────────────────────────────────────────────
// Bookmark
// ──────────────────────────────────────────────────────────────

enum BookmarkType { progress, note }

class Bookmark {
  final String id;
  final String label;
  final double progress; // 0.0 – 1.0
  final BookmarkType type;
  final DateTime createdAt;
  final String? quote;

  Bookmark({
    required this.id,
    required this.label,
    required this.progress,
    required this.type,
    required this.createdAt,
    this.quote,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'progress': progress,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'quote': quote,
      };

  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(
        id: (j['id'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        progress: ((j['progress'] ?? 0.0) as num).toDouble(),
        type: j['type'] == 'note' ? BookmarkType.note : BookmarkType.progress,
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        quote: j['quote']?.toString(),
      );
}

// ──────────────────────────────────────────────────────────────
// Paper
// ──────────────────────────────────────────────────────────────

class Paper {
  final String id;
  final String title;
  final String authors;
  final String category; // maps to journal/source from backend
  final String year;
  final String status; // unread | reading | analyzed | read
  final double progress;
  final String? url;
  final String? pdfUrl;     // ← NEW: open-access PDF URL
  final String? abstract;
  final String? summary;
  final bool isFavorite;
  final List<Bookmark> bookmarks;   // ← NEW
  final DateTime? lastReadAt;       // ← NEW
  final int totalReadingTimeSeconds; // ← NEW

  Paper({
    required this.id,
    required this.title,
    required this.authors,
    required this.category,
    required this.year,
    required this.status,
    this.progress = 0.0,
    this.url,
    this.pdfUrl,
    this.abstract,
    this.summary,
    this.isFavorite = false,
    this.bookmarks = const [],
    this.lastReadAt,
    this.totalReadingTimeSeconds = 0,
  });

  Paper copyWith({
    String? status,
    double? progress,
    bool? isFavorite,
    String? pdfUrl,
    List<Bookmark>? bookmarks,
    DateTime? lastReadAt,
    int? totalReadingTimeSeconds,
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
        pdfUrl: pdfUrl ?? this.pdfUrl,
        abstract: abstract,
        summary: summary,
        isFavorite: isFavorite ?? this.isFavorite,
        bookmarks: bookmarks ?? this.bookmarks,
        lastReadAt: lastReadAt ?? this.lastReadAt,
        totalReadingTimeSeconds:
            totalReadingTimeSeconds ?? this.totalReadingTimeSeconds,
      );

  /// Deserialise from backend JSON — tolerates missing/null fields (OLD data safe)
  factory Paper.fromJson(Map<String, dynamic> j) => Paper(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? 'Untitled').toString(),
        authors: (j['authors'] ?? '').toString(),
        category: ((j['journal'] ?? j['source'] ?? 'General')).toString(),
        year: (j['year'] ?? '').toString(),
        status: (j['status'] ?? 'unread').toString(),
        progress: ((j['progress'] ?? 0.0) as num).toDouble(),
        url: j['url']?.toString(),
        pdfUrl: j['pdf_url']?.toString(),
        abstract: j['abstract']?.toString(),
        summary: j['summary']?.toString() ?? j['ai_summary']?.toString(),
        isFavorite: j['is_favorite'] == true,
        // bookmarks, lastReadAt, totalReadingTimeSeconds loaded from local prefs
        bookmarks: const [],
        lastReadAt: null,
        totalReadingTimeSeconds: 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'authors': authors,
        'journal': category,
        'year': year,
        'status': status,
        'progress': progress,
        'url': url,
        'pdf_url': pdfUrl,
        'abstract': abstract,
        'summary': summary,
        'is_favorite': isFavorite,
        'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
        'lastReadAt': lastReadAt?.toIso8601String(),
        'totalReadingTimeSeconds': totalReadingTimeSeconds,
      };
}

// ──────────────────────────────────────────────────────────────
// PapersService
// ──────────────────────────────────────────────────────────────

class PapersService {
  static final PapersService _instance = PapersService._internal();
  factory PapersService() => _instance;
  PapersService._internal();

  List<Paper> _papers = [];
  bool _isInitialized = false;

  List<Paper> get papers => List.unmodifiable(_papers);
  bool get isInitialized => _isInitialized;

  // ── SharedPrefs keys ──────────────────────────────────────
  static const _prefsKeyPrefix = 'paper_local_'; // prefix for per-paper blobs

  String get baseUrl {
    if (kIsWeb) return 'http://localhost:8001';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8001';
    }
    return 'http://localhost:8001';
  }

  // ── Initialize ────────────────────────────────────────────
  Future<void> initialize() async {
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
        final serverPapers =
            list.map((e) => Paper.fromJson(e as Map<String, dynamic>)).toList();
        // Merge local prefs data
        _papers = await _mergeLocalData(serverPapers);
        _sortPapers();
      } else {
        debugPrint('[Papers] fetch error ${r.statusCode}: ${r.body}');
      }
    } catch (e) {
      debugPrint('[Papers] fetch exception: $e');
    }
  }

  // Merge bookmarks / lastReadAt / totalReadingTimeSeconds from SharedPrefs
  Future<List<Paper>> _mergeLocalData(List<Paper> papers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return papers.map((p) {
        final key = '$_prefsKeyPrefix${p.id}';
        final raw = prefs.getString(key);
        if (raw == null) return p;
        try {
          final j = jsonDecode(raw) as Map<String, dynamic>;
          final bList = (j['bookmarks'] as List? ?? [])
              .map((b) => Bookmark.fromJson(b as Map<String, dynamic>))
              .toList();
          final lastReadAt = j['lastReadAt'] != null
              ? DateTime.tryParse(j['lastReadAt'].toString())
              : null;
          final totalSec = (j['totalReadingTimeSeconds'] as num?)?.toInt() ?? 0;
          return p.copyWith(
            bookmarks: bList,
            lastReadAt: lastReadAt,
            totalReadingTimeSeconds: totalSec,
          );
        } catch (_) {
          return p;
        }
      }).toList();
    } catch (e) {
      debugPrint('[Papers] mergeLocalData error: $e');
      return papers;
    }
  }

  // Persist local fields for one paper
  Future<void> _saveLocalData(Paper paper) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefsKeyPrefix${paper.id}';
      final j = {
        'bookmarks': paper.bookmarks.map((b) => b.toJson()).toList(),
        'lastReadAt': paper.lastReadAt?.toIso8601String(),
        'totalReadingTimeSeconds': paper.totalReadingTimeSeconds,
      };
      await prefs.setString(key, jsonEncode(j));
    } catch (e) {
      debugPrint('[Papers] saveLocalData error: $e');
    }
  }

  void _sortPapers() {
    _papers.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      // Secondary: most recently read first
      final aTime = a.lastReadAt;
      final bTime = b.lastReadAt;
      if (aTime != null && bTime != null) return bTime.compareTo(aTime);
      if (aTime != null) return -1;
      if (bTime != null) return 1;
      return 0;
    });
  }

  // ── Reload ────────────────────────────────────────────────
  Future<void> reload() async => _fetchPapers();

  // ── Add Paper ──────────────────────────────────────────────
  /// Avoids duplicates: matches by id, then DOI-derived url, then normalised title.
  Future<void> addPaper(Paper paper) async {
    // Duplicate check (in-memory)
    final isDuplicate = _papers.any((p) {
      if (p.id == paper.id) return true;
      if (paper.url != null &&
          paper.url!.isNotEmpty &&
          p.url != null &&
          p.url!.isNotEmpty) {
        if (p.url!.trim().toLowerCase() == paper.url!.trim().toLowerCase()) {
          return true;
        }
      }
      return p.title.trim().toLowerCase() == paper.title.trim().toLowerCase();
    });

    if (isDuplicate) {
      debugPrint('[Papers] addPaper: duplicate skipped "${paper.title}"');
      return;
    }

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
        'pdf_url': paper.pdfUrl ?? '',
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

  // ── Delete ────────────────────────────────────────────────
  Future<void> deletePaper(String id) async {
    try {
      await http
          .delete(Uri.parse('$baseUrl/api/papers/$id'))
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[Papers] deletePaper exception: $e');
    }
    // Clear local prefs
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefsKeyPrefix$id');
    } catch (_) {}
    _papers.removeWhere((p) => p.id == id);
  }

  // ── Toggle favourite ──────────────────────────────────────
  Future<void> toggleFavorite(String id) async {
    final idx = _papers.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _papers[idx] =
          _papers[idx].copyWith(isFavorite: !_papers[idx].isFavorite);
      _sortPapers();
    }
  }

  // ── Update progress ───────────────────────────────────────
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
    final idx = _papers.indexWhere((p) => p.id == id);
    if (idx != -1) {
      final updated = _papers[idx].copyWith(
        status: status,
        progress: progress,
        lastReadAt: DateTime.now(),
      );
      _papers[idx] = updated;
      await _saveLocalData(updated);
      _sortPapers();
    }
  }

  // ── Reading time ──────────────────────────────────────────
  Future<void> updateReadingTime(String paperId, int additionalSeconds) async {
    final idx = _papers.indexWhere((p) => p.id == paperId);
    if (idx == -1) return;
    final p = _papers[idx];
    final updated = p.copyWith(
      totalReadingTimeSeconds: p.totalReadingTimeSeconds + additionalSeconds,
      lastReadAt: DateTime.now(),
    );
    _papers[idx] = updated;
    await _saveLocalData(updated);
  }

  // ── Bookmarks ─────────────────────────────────────────────
  Future<void> addBookmark(String paperId, Bookmark bookmark) async {
    final idx = _papers.indexWhere((p) => p.id == paperId);
    if (idx == -1) return;
    final p = _papers[idx];
    final updated = p.copyWith(
      bookmarks: [...p.bookmarks, bookmark],
    );
    _papers[idx] = updated;
    await _saveLocalData(updated);
  }

  Future<void> removeBookmark(String paperId, String bookmarkId) async {
    final idx = _papers.indexWhere((p) => p.id == paperId);
    if (idx == -1) return;
    final p = _papers[idx];
    final updated = p.copyWith(
      bookmarks: p.bookmarks.where((b) => b.id != bookmarkId).toList(),
    );
    _papers[idx] = updated;
    await _saveLocalData(updated);
  }

  // ── Export notes ──────────────────────────────────────────
  /// Returns a Markdown-formatted string of all bookmarks/notes for a paper.
  String exportNotes(String paperId) {
    final idx = _papers.indexWhere((p) => p.id == paperId);
    if (idx == -1) return '';
    final paper = _papers[idx];

    final buf = StringBuffer();
    buf.writeln('# Notes: ${paper.title}');
    buf.writeln('**Authors:** ${paper.authors}');
    buf.writeln('**Year:** ${paper.year}');
    buf.writeln('**Progress:** ${(paper.progress * 100).round()}%');
    buf.writeln();

    if (paper.bookmarks.isEmpty) {
      buf.writeln('_No highlights or notes yet._');
      return buf.toString();
    }

    buf.writeln('## Highlights & Notes');
    buf.writeln();
    for (final b in paper.bookmarks) {
      final ts = b.createdAt.toLocal().toString().substring(0, 16);
      if (b.type == BookmarkType.note) {
        buf.writeln('### 📝 ${b.label}');
        if (b.quote != null && b.quote!.isNotEmpty) {
          buf.writeln('> ${b.quote}');
          buf.writeln();
        }
        buf.writeln('*Added at ${(b.progress * 100).round()}% · $ts*');
      } else {
        buf.writeln('### 🔖 ${b.label}');
        buf.writeln('*Progress marker at ${(b.progress * 100).round()}% · $ts*');
      }
      buf.writeln();
    }
    return buf.toString();
  }

  // ── Filter helpers ────────────────────────────────────────
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

  /// Returns the most recently read paper with status 'reading', or null.
  Paper? getMostRecentlyReading() {
    final reading = _papers
        .where((p) => p.status == 'reading' && p.lastReadAt != null)
        .toList();
    if (reading.isEmpty) return null;
    reading.sort((a, b) => b.lastReadAt!.compareTo(a.lastReadAt!));
    return reading.first;
  }
}
