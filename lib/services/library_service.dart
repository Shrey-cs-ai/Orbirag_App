import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LibraryItem {
  final String id;
  final String title;
  final String description;
  final String type; // 'insight', 'draft', 'citation', 'idea', 'note', 'paper'
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type,
    'createdAt': createdAt.toIso8601String(),
    'isPinned': isPinned,
  };

  factory LibraryItem.fromJson(Map<String, dynamic> json) => LibraryItem(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    type: json['type'],
    createdAt: DateTime.parse(json['createdAt']),
    isPinned: json['isPinned'] ?? false,
  );
}

class LibraryService {
  static final LibraryService _instance = LibraryService._internal();
  factory LibraryService() => _instance;
  LibraryService._internal();

  List<LibraryItem> _items = [];
  bool _isInitialized = false;

  List<LibraryItem> get items => _items;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadItems();
    _isInitialized = true;
  }

  Future<void> _loadItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final itemsJson = prefs.getString('library_items');
      if (itemsJson != null) {
        final List<dynamic> decoded = jsonDecode(itemsJson);
        _items = decoded
            .map((e) => LibraryItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _sortItems();
      } else {
        _items = _getSampleItems();
        await _saveItems();
      }
    } catch (e) {
      debugPrint('Error loading library: $e');
    }
  }

  List<LibraryItem> _getSampleItems() {
    final now = DateTime.now();
    return [
      LibraryItem(
        id: '1',
        title: 'Discrepancy in reported clinician trust as AI warnings vs. actual utilization',
        description:
            'Found that urban tertiary doctors report 72% confidence in AI warnings vs. only 34% in...',
        type: 'insight',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      LibraryItem(
        id: '2',
        title: 'Methodology: Sampling Strategy Draft',
        description:
            '"The research cohort comprises N = 240 practitioners selected through multi-stage..."',
        type: 'draft',
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
      LibraryItem(
        id: '3',
        title: 'Karki, P., & Bhatta, R. (2022)',
        description: 'Evaluating health facility preparedness...',
        type: 'citation',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      LibraryItem(
        id: '4',
        title: 'Hybrid offline-first cache for village health workers',
        description:
            'Could we test local SQLite vector embedding models on Android Go devices?',
        type: 'idea',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      LibraryItem(
        id: '5',
        title: 'Advisor feedback on Chapter 3 statistical model',
        description: 'Prof. Pradhan noted to mention effect size...',
        type: 'note',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ];
  }

  Future<void> _saveItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final itemsJson = jsonEncode(_items.map((e) => e.toJson()).toList());
      await prefs.setString('library_items', itemsJson);
    } catch (e) {
      debugPrint('Error saving library: $e');
    }
  }

  void _sortItems() {
    _items.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  Future<void> addItem(LibraryItem item) async {
    _items.insert(0, item);
    _sortItems();
    await _saveItems();
  }

  Future<void> deleteItem(String id) async {
    _items.removeWhere((item) => item.id == id);
    await _saveItems();
  }

  Future<void> togglePin(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      _items[index] = LibraryItem(
        id: _items[index].id,
        title: _items[index].title,
        description: _items[index].description,
        type: _items[index].type,
        createdAt: _items[index].createdAt,
        isPinned: !_items[index].isPinned,
      );
      _sortItems();
      await _saveItems();
    }
  }

  List<LibraryItem> searchItems(String query) {
    if (query.isEmpty) return _items;
    return _items
        .where((item) =>
            item.title.toLowerCase().contains(query.toLowerCase()) ||
            item.description.toLowerCase().contains(query.toLowerCase()) ||
            item.type.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  String getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}