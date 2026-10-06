import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/app_constants.dart';

// ============================================================
// Model
// ============================================================
class Note {
  final String id;
  String title;
  String content;
  DateTime createdAt;
  DateTime updatedAt;
  bool isPinned;

  Note({
    required this.id,
    required this.title,
    required this.content,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isPinned = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'].toString(),
        title: json['title'] ?? 'Untitled',
        content: json['content'] ?? '',
        createdAt: DateTime.parse(json['created_at']).toLocal(),
        updatedAt: DateTime.parse(json['updated_at']).toLocal(),
        isPinned: json['is_pinned'] ?? false,
      );

  Map<String, dynamic> toCreateJson() => {
        'title': title,
        'content': content,
      };

  Map<String, dynamic> toUpdateJson() => {
        'title': title,
        'content': content,
        'is_pinned': isPinned,
      };
}

// ============================================================
// Service
// ============================================================
class NotesService {
  static final NotesService _instance = NotesService._internal();
  factory NotesService() => _instance;
  NotesService._internal();

  String get _baseUrl => AppConstants.researchBaseUrl;
  List<Note> _notes = [];

  List<Note> get notes => _notes;

  // ---------- Read ----------
  Future<void> initialize() async {
    await refresh();
  }

  Future<void> refresh({String? search}) async {
    try {
      final uri = Uri.parse('$_baseUrl/notes/items').replace(
        queryParameters: (search != null && search.isNotEmpty)
            ? {'search': search}
            : null,
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Failed to load notes: ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['items'] as List).cast<Map<String, dynamic>>();
      _notes = list.map(Note.fromJson).toList();
    } catch (e) {
      debugPrint('NotesService.refresh error: $e');
      rethrow;
    }
  }

  List<Note> searchNotes(String query) {
    if (query.isEmpty) return _notes;
    final q = query.toLowerCase();
    return _notes
        .where((n) =>
            n.title.toLowerCase().contains(q) ||
            n.content.toLowerCase().contains(q))
        .toList();
  }

  // ---------- Create ----------
  Future<Note> addNote(Note note) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/notes/items'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(note.toCreateJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create note: ${response.statusCode}');
    }
    final created = Note.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    _notes.insert(0, created);
    _sort();
    return created;
  }

  // ---------- Update (used by auto-save) ----------
  Future<Note> updateNote(Note note) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/notes/items/${note.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(note.toUpdateJson()),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update note: ${response.statusCode}');
    }
    final updated = Note.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );

    final index = _notes.indexWhere((n) => n.id == updated.id);
    if (index != -1) {
      _notes[index] = updated;
    } else {
      _notes.insert(0, updated);
    }
    _sort();
    return updated;
  }

  // ---------- Pin ----------
  Future<void> togglePinNote(String id) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/notes/items/$id/pin'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to toggle pin: ${response.statusCode}');
    }
    await refresh();
  }

  // ---------- Delete ----------
  Future<void> deleteNote(String id) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/notes/items/$id'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete note: ${response.statusCode}');
    }
    _notes.removeWhere((n) => n.id == id);
  }

  // ---------- Helpers ----------
  void _sort() {
    _notes.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }
}