import 'dart:convert';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:http/http.dart' as http;

// ============================================================
// Model — matches methodology_form.dart field names
// ============================================================
class MethodologyData {
  String studyType;
  String design;
  String sampleSize;
  String samplingMethod;
  String dataCollection;
  String analysisMethod;
  String databasesSearched;
  String inclusionCriteria;
  String exclusionCriteria;
  String studiesIncludedCount;
  String additionalNotes;
  String rawHighlightedText;

  MethodologyData({
    this.studyType = '',
    this.design = '',
    this.sampleSize = '',
    this.samplingMethod = '',
    this.dataCollection = '',
    this.analysisMethod = '',
    this.databasesSearched = '',
    this.inclusionCriteria = '',
    this.exclusionCriteria = '',
    this.studiesIncludedCount = '',
    this.additionalNotes = '',
    this.rawHighlightedText = '',
  });

  factory MethodologyData.fromJson(Map<String, dynamic> j) => MethodologyData(
        studyType: (j['study_type'] ?? '').toString(),
        design: (j['design'] ?? '').toString(),
        sampleSize: (j['sample_size'] ?? '').toString(),
        samplingMethod: (j['sampling_method'] ?? '').toString(),
        dataCollection: (j['data_collection'] ?? '').toString(),
        analysisMethod: (j['analysis_method'] ?? '').toString(),
        databasesSearched: (j['databases_searched'] ?? '').toString(),
        inclusionCriteria: (j['inclusion_criteria'] ?? '').toString(),
        exclusionCriteria: (j['exclusion_criteria'] ?? '').toString(),
        studiesIncludedCount: (j['studies_included_count'] ?? '').toString(),
        additionalNotes: (j['additional_notes'] ?? '').toString(),
        rawHighlightedText: (j['raw_highlighted_text'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'study_type': studyType,
        'design': design,
        'sample_size': sampleSize,
        'sampling_method': samplingMethod,
        'data_collection': dataCollection,
        'analysis_method': analysisMethod,
        'databases_searched': databasesSearched,
        'inclusion_criteria': inclusionCriteria,
        'exclusion_criteria': exclusionCriteria,
        'studies_included_count': studiesIncludedCount,
        'additional_notes': additionalNotes,
        'raw_highlighted_text': rawHighlightedText,
      };

  String? get paperTitle {
    if (additionalNotes.isNotEmpty) return additionalNotes;
    if (design.isNotEmpty) return design;
    return null;
  }
}

// ============================================================
// Service
// ============================================================
class MethodologyService {
  static final MethodologyService instance = MethodologyService._internal();
  factory MethodologyService() => instance;
  MethodologyService._internal();

  String get baseUrl {
    if (kIsWeb) return 'http://localhost:8001';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8001';
    }
    return 'http://localhost:8001';
  }

  // ---------- EXTRACT ----------
  Future<MethodologyData?> extractMethodology(
    String text, {
    String? paperTitle,
  }) async {
    try {
      final r = await http
          .post(
            Uri.parse('$baseUrl/api/methodology/extract'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': text,
              'paper_title': paperTitle,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (r.statusCode != 200) {
        debugPrint('[Methodology] extract failed: ${r.statusCode} ${r.body}');
        return null;
      }
      final json = jsonDecode(r.body) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>? ?? {};
      return MethodologyData.fromJson(data);
    } catch (e) {
      debugPrint('[Methodology] extract exception: $e');
      return null;
    }
  }

  // ---------- SAVE ----------
  Future<bool> saveMethodology(
    MethodologyData data, {
    String? paperTitle,
    String? rawText,
  }) async {
    try {
      final r = await http
          .post(
            Uri.parse('$baseUrl/api/methodology/save'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'paper_title': paperTitle,
              'raw_text': rawText ?? data.rawHighlightedText,
              'data': data.toJson(),
              'user_id': null,
            }),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('[Methodology] save status: ${r.statusCode}');
      return r.statusCode == 200;
    } catch (e) {
      debugPrint('[Methodology] save exception: $e');
      return false;
    }
  }

  // ---------- HISTORY ----------
  Future<List<Map<String, dynamic>>> listHistory() async {
    try {
      final r = await http
          .get(Uri.parse('$baseUrl/api/methodology/history'))
          .timeout(const Duration(seconds: 30));
      if (r.statusCode != 200) return [];
      final json = jsonDecode(r.body) as Map<String, dynamic>;
      return (json['items'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[Methodology] history exception: $e');
      return [];
    }
  }
}