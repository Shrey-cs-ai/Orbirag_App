import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/app_constants.dart';

// ============================================================
// Model
// ============================================================
class LibraryItem {
  final String id;
  final String title;
  final String description;
  final String type; // 'insight', 'draft', 'citation', 'idea', 'note'
  final DateTime createdAt;
  final bool isPinned;

  LibraryItem({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.createdAt,
    this.isPinned = false,
  });

  factory LibraryItem.fromJson(Map<String, dynamic> json) => LibraryItem(
        id: json['id'].toString(),
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        type: json['type'] ?? 'note',
        createdAt: DateTime.parse(json['created_at']).toLocal(),
        isPinned: json['is_pinned'] ?? false,
      );

  Map<String, dynamic> toCreateJson() => {
        'title': title,
        'description': description,
        'type': type,
      };
}

// ============================================================
// Service
// ============================================================
class LibraryService {
  static final LibraryService _instance = LibraryService._internal();
  factory LibraryService() => _instance;
  LibraryService._internal();

  String get _baseUrl => AppConstants.researchBaseUrl;
  List<LibraryItem> _items = [];

  List<LibraryItem> get items => _items;

  // ---------- Read ----------
  Future<void> initialize() async {
    await refresh();
  }

  Future<void> refresh({String? search}) async {
    try {
      final uri = Uri.parse('$_baseUrl/library/items').replace(
        queryParameters: (search != null && search.isNotEmpty)
            ? {'search': search}
            : null,
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Failed to load: ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['items'] as List).cast<Map<String, dynamic>>();
      _items = list.map(LibraryItem.fromJson).toList();
    } catch (e) {
      debugPrint('LibraryService.refresh error: $e');
      rethrow;
    }
  }

  List<LibraryItem> searchItems(String query) {
    if (query.isEmpty) return _items;
    final q = query.toLowerCase();
    return _items
        .where((i) =>
            i.title.toLowerCase().contains(q) ||
            i.description.toLowerCase().contains(q) ||
            i.type.toLowerCase().contains(q))
        .toList();
  }

  // ---------- Create ----------
  Future<LibraryItem> addItem(LibraryItem item) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/library/items'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(item.toCreateJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create: ${response.statusCode}');
    }
    final created = LibraryItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    _items.insert(0, created);
    return created;
  }

  // ---------- Pin ----------
  Future<void> togglePin(String id) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/library/items/$id/pin'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to toggle pin: ${response.statusCode}');
    }
    await refresh();
  }

  // ---------- Delete ----------
  Future<void> deleteItem(String id) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/library/items/$id'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete: ${response.statusCode}');
    }
    _items.removeWhere((i) => i.id == id);
  }

  // ---------- Helpers ----------
  String getTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}