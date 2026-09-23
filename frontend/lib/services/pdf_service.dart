// lib/services/pdf_service.dart
import 'dart:io';

import 'ai_service.dart';

class PdfService {
  static final PdfService _instance = PdfService._internal();
  factory PdfService() => _instance;
  PdfService._internal();

  final List<Map<String, dynamic>> _sources = [];

  List<Map<String, dynamic>> get sources => _sources;

  // ============================================================
  // Upload a PDF file to backend and add it to sources list.
  // ============================================================
  Future<void> addPdf(File file) async {
    try {
      final response = await AiService.instance.uploadPdf(file.path);

      _sources.add({
        'type': 'pdf',
        'name': response['filename'] ?? file.path.split('/').last,
        'paper_id': response['paper_id'],
        'chunks': response['chunk_count'],
        'pages': '${response['chunk_count']} chunks',
        'size': _formatFileSize(file.lengthSync()),
        'dateAdded': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to upload PDF: $e');
    }
  }

  // ============================================================
  // Add raw text (local only — backend text upload not built yet).
  // ============================================================
  Future<void> addText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _sources.add({
      'type': 'text',
      'name': 'Pasted text ${_sources.length + 1}',
      'content': trimmed,
      'paper_id': null,
      'pages': '${trimmed.split(RegExp(r'\s+')).length} words',
      'size': '${trimmed.length} chars',
      'dateAdded': DateTime.now().toIso8601String(),
    });
  }

  // ============================================================
  // Remove a single source by index.
  // ============================================================
  void removeSource(int index) {
    if (index >= 0 && index < _sources.length) {
      _sources.removeAt(index);
    }
  }

  // ============================================================
  // Clear all sources.
  // ============================================================
  void clearSources() {
    _sources.clear();
  }

  // ============================================================
  // Get the first source that has a valid paper_id.
  // ============================================================
  Map<String, dynamic>? get firstPdfSource {
    for (final source in _sources) {
      if (source['paper_id'] != null) return source;
    }
    return null;
  }

  // ============================================================
  // Check if there's at least one chat-ready source.
  // ============================================================
  bool get hasChatReadySource => firstPdfSource != null;

  // ============================================================
  // Human-readable file size.
  // ============================================================
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}