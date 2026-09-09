import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Note {
  final String id;
  String title;
  String content;
  DateTime updatedAt;
  bool isPinned;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
    this.isPinned = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'updatedAt': updatedAt.toIso8601String(),
    'isPinned': isPinned,
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'],
    title: json['title'],
    content: json['content'],
    updatedAt: DateTime.parse(json['updatedAt']),
    isPinned: json['isPinned'] ?? false,
  );
}

class NotesService {
  static final NotesService _instance = NotesService._internal();
  factory NotesService() => _instance;
  NotesService._internal();

  List<Note> _notes = [];
  bool _isInitialized = false;

  List<Note> get notes => _notes;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadNotes();
    _isInitialized = true;
  }

  Future<void> _loadNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesJson = prefs.getString('notes');
      if (notesJson != null) {
        final List<dynamic> decoded = jsonDecode(notesJson);
        _notes = decoded.map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
        _sortNotes();
      } else {
        // Add sample notes for first launch
        _notes = [
          Note(
            id: '1',
            title: 'AI Research Idea',
            content: 'Explore how artificial intelligence can improve disease detection in early-stage diagnostics. Focus on deep learning models and their application in radiology.',
            updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
          Note(
            id: '2',
            title: 'Literature Notes',
            content: 'Key takeaways from the Smith et al. (2023) paper on neural networks: The primary contribution is a novel architecture for medical image segmentation. The model achieved 94.7% accuracy on the test dataset.',
            updatedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
          Note(
            id: '3',
            title: 'Methodology Thought',
            content: 'Possible quantitative approach for the upcoming study involves a mixed-methods design. Consider using surveys for data collection and statistical analysis for hypothesis testing.',
            updatedAt: DateTime.now().subtract(const Duration(days: 3)),
          ),
        ];
        await _saveNotes();
      }
    } catch (e) {
      print('Error loading notes: $e');
    }
  }

  Future<void> _saveNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesJson = jsonEncode(_notes.map((e) => e.toJson()).toList());
      await prefs.setString('notes', notesJson);
    } catch (e) {
      print('Error saving notes: $e');
    }
  }

  void _sortNotes() {
    _notes.sort((a, b) {
      // Pinned notes first
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      // Then by updated date
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  Future<void> addNote(Note note) async {
    _notes.insert(0, note);
    _sortNotes();
    await _saveNotes();
  }

  Future<void> updateNote(Note note) async {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      _notes[index] = note;
      _sortNotes();
      await _saveNotes();
    }
  }

  Future<void> deleteNote(String id) async {
    _notes.removeWhere((n) => n.id == id);
    await _saveNotes();
  }

  Future<void> togglePinNote(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notes[index].isPinned = !_notes[index].isPinned;
      _sortNotes();
      await _saveNotes();
    }
  }

  List<Note> searchNotes(String query) {
    if (query.isEmpty) return _notes;
    return _notes.where((note) =>
      note.title.toLowerCase().contains(query.toLowerCase()) ||
      note.content.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }
}