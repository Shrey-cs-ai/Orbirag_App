import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ==================== MODEL ====================

class MethodologyData {
  String studyType; // quantitative, qualitative, mixed-methods, systematic-review, case-study, other
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

  factory MethodologyData.fromJson(Map<String, dynamic> json) {
    return MethodologyData(
      studyType: json['studyType'] ?? '',
      design: json['design'] ?? '',
      sampleSize: json['sampleSize'] ?? '',
      samplingMethod: json['samplingMethod'] ?? '',
      dataCollection: json['dataCollection'] ?? '',
      analysisMethod: json['analysisMethod'] ?? '',
      databasesSearched: json['databasesSearched'] ?? '',
      inclusionCriteria: json['inclusionCriteria'] ?? '',
      exclusionCriteria: json['exclusionCriteria'] ?? '',
      studiesIncludedCount: json['studiesIncludedCount']?.toString() ?? '',
      additionalNotes: json['additionalNotes'] ?? '',
      rawHighlightedText: json['rawHighlightedText'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'studyType': studyType,
        'design': design,
        'sampleSize': sampleSize,
        'samplingMethod': samplingMethod,
        'dataCollection': dataCollection,
        'analysisMethod': analysisMethod,
        'databasesSearched': databasesSearched,
        'inclusionCriteria': inclusionCriteria,
        'exclusionCriteria': exclusionCriteria,
        'studiesIncludedCount': studiesIncludedCount,
        'additionalNotes': additionalNotes,
        'rawHighlightedText': rawHighlightedText,
      };

  String get summary {
    final parts = <String>[];
    if (studyType.isNotEmpty) parts.add(studyType.toUpperCase());
    if (sampleSize.isNotEmpty) parts.add(sampleSize);
    if (dataCollection.isNotEmpty) parts.add(dataCollection);
    return parts.isEmpty ? 'No methodology extracted yet' : parts.join(' · ');
  }
}

// ==================== SERVICE ====================

class MethodologyService {
  static final MethodologyService instance = MethodologyService._internal();
  MethodologyService._internal();

  static const String _baseUrl = 'http://10.0.2.2:8000';

  /// Call AI to extract methodology from highlighted text
  Future<MethodologyData?> extractMethodology(String highlightedText) async {
    if (highlightedText.trim().isEmpty) return null;

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/ai/extract-methodology'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': highlightedText}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = MethodologyData.fromJson(data);
        result.rawHighlightedText = highlightedText;
        return result;
      }
    } catch (e) {
      debugPrint('Extraction error: $e');
    }
    return null;
  }

  /// Save methodology notes to backend
  Future<bool> saveMethodology(MethodologyData data) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/methodology'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data.toJson()),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Save error: $e');
      return false;
    }
  }
}