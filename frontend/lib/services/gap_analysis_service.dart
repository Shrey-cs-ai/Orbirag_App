import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/gap_analysis_models.dart';
import '../utils/app_constants.dart';
import '../utils/firebase_auth_service.dart';

class GapAnalysisService {
  static final GapAnalysisService _instance = GapAnalysisService._internal();
  factory GapAnalysisService() => _instance;
  GapAnalysisService._internal();

  String get _baseUrl => AppConstants.researchBaseUrl;

  Map<String, String> get _headers {
    final uid = FirebaseAuthService.instance.currentUser?.uid;
    return {
      'Content-Type': 'application/json',
      if (uid != null) 'x-user-id': uid,
    };
  }

  Future<GapAnalysisResult> analyze({
    required String topic,
    String? researchQuestion,
    List<String>? keywords,
    Map<String, dynamic>? scopeFilters,
    required List<String> paperIds,
    List<Map<String, dynamic>>? papers,
  }) async {
    final uri = Uri.parse('$_baseUrl/gap/analyze');
    final payload = {
      'topic': topic,
      'research_question': researchQuestion,
      'keywords': keywords,
      'scope_filters': scopeFilters,
      'paper_ids': paperIds,
      if (papers != null) 'papers': papers,
    };

    final resp = await http
        .post(uri, headers: _headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 120));

    if (resp.statusCode != 200) {
      debugPrint('[GapService] analyze failed: ${resp.statusCode} — ${resp.body}');
      throw Exception('Analysis failed: ${resp.statusCode}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return GapAnalysisResult.fromJson(data);
  }

  Future<PaperEvidence> extractPaper(Map<String, dynamic> paper) async {
    final uri = Uri.parse('$_baseUrl/gap/extract');
    final resp = await http
        .post(uri, headers: _headers, body: jsonEncode({'paper': paper}))
        .timeout(const Duration(seconds: 45));

    if (resp.statusCode != 200) {
      debugPrint('[GapService] extract failed: ${resp.statusCode} — ${resp.body}');
      throw Exception('Evidence extraction failed: ${resp.statusCode}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return PaperEvidence.fromJson(data);
  }

  Future<List<ResearchDirection>> directions(
    GapCandidate gap, {
    required String topic,
    String? researchQuestion,
  }) async {
    final uri = Uri.parse('$_baseUrl/gap/directions');
    final payload = {
      'gap': gap.toJson(),
      'topic': topic,
      'research_question': researchQuestion,
    };

    final resp = await http
        .post(uri, headers: _headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 60));

    if (resp.statusCode != 200) {
      debugPrint('[GapService] directions failed: ${resp.statusCode} — ${resp.body}');
      throw Exception('Directions failed: ${resp.statusCode}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = (data['directions'] as List? ?? [])
        .map((d) => ResearchDirection.fromJson(d as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<GapReport> saveReport(GapReport draft) async {
    final uri = Uri.parse('$_baseUrl/gap/reports');
    final resp = await http
        .post(uri, headers: _headers, body: jsonEncode(draft.toJson()))
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      debugPrint('[GapService] saveReport failed: ${resp.statusCode} — ${resp.body}');
      throw Exception('Failed to save report: ${resp.statusCode}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return GapReport.fromJson(data);
  }

  Future<List<GapReport>> listReports() async {
    final uri = Uri.parse('$_baseUrl/gap/reports');
    final resp = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      debugPrint('[GapService] listReports failed: ${resp.statusCode} — ${resp.body}');
      throw Exception('Failed to list reports: ${resp.statusCode}');
    }

    final list = jsonDecode(resp.body) as List;
    return list.map((item) => GapReport.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<GapReport> getReport(String id) async {
    final uri = Uri.parse('$_baseUrl/gap/reports/$id');
    final resp = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      debugPrint('[GapService] getReport failed: ${resp.statusCode} — ${resp.body}');
      throw Exception('Failed to get report: ${resp.statusCode}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return GapReport.fromJson(data);
  }

  Future<void> updateReport(String id, Map<String, dynamic> patch) async {
    final uri = Uri.parse('$_baseUrl/gap/reports/$id');
    final resp = await http
        .patch(uri, headers: _headers, body: jsonEncode(patch))
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      debugPrint('[GapService] updateReport failed: ${resp.statusCode} — ${resp.body}');
      throw Exception('Failed to update report: ${resp.statusCode}');
    }
  }

  Future<void> deleteReport(String id) async {
    final uri = Uri.parse('$_baseUrl/gap/reports/$id');
    final resp = await http
        .delete(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      debugPrint('[GapService] deleteReport failed: ${resp.statusCode} — ${resp.body}');
      throw Exception('Failed to delete report: ${resp.statusCode}');
    }
  }
}
