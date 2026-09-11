// lib/services/pdf_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart'; // ✅ For debugPrint and kDebugMode

class PdfService {
  static final PdfService _instance = PdfService._internal();
  factory PdfService() => _instance;
  PdfService._internal();

  final List<Map<String, dynamic>> _sources = [];

  List<Map<String, dynamic>> get sources => _sources;

  Future<void> addPdf(File file) async {
    try {
      _sources.add({
        'name': file.path.split('/').last,
        'path': file.path,
        'pages': 'PDF Document',
        'size': _formatFileSize(file.lengthSync()),
        'dateAdded': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error adding PDF: $e'); // ✅ Works with foundation import
    }
  }

  void removeSource(int index) {
    if (index < _sources.length) {
      _sources.removeAt(index);
    }
  }

  void clearSources() {
    _sources.clear();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
