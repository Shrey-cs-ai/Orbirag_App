import 'ai_service.dart';

class PdfService {
  static final PdfService _instance = PdfService._internal();
  factory PdfService() => _instance;
  PdfService._internal();

  final List<Map<String, dynamic>> _sources = [];

  List<Map<String, dynamic>> get sources => _sources;

  // ✅ Calls the backend to upload the PDF and saves the paper_id
  Future<void> addPdf(List<int> fileBytes, String filename) async {
    try {
      final response = await AiService.instance.uploadPdf(
        fileBytes: fileBytes,
        filename: filename,
      );

      _sources.add({
        'type': 'pdf',
        'name': response['filename'] ?? filename,
        'paper_id': response['paper_id'], // 👈 Critical for Chat with PDF!
        'chunks': response['chunk_count'],
        'pages': '${response['chunk_count']} chunks',
        'size': '${(fileBytes.length / 1024).toStringAsFixed(1)} KB',
        'dateAdded': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to upload PDF: $e');
    }
  }

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

  void removeSource(int index) {
    if (index >= 0 && index < _sources.length) {
      _sources.removeAt(index);
    }
  }

  void clearSources() => _sources.clear();

  Map<String, dynamic>? get firstPdfSource {
    for (final source in _sources) {
      if (source['paper_id'] != null) return source;
    }
    return null;
  }

  bool get hasChatReadySource => firstPdfSource != null;
}