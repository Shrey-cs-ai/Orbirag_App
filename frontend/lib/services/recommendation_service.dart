import 'dart:convert';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:http/http.dart' as http;
import 'search_service.dart';

class RecommendationService {
  static final RecommendationService instance =
      RecommendationService._internal();
  factory RecommendationService() => instance;
  RecommendationService._internal();

  String get baseUrl {
    if (kIsWeb) return 'http://localhost:8001';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8001';
    }
    return 'http://localhost:8001';
  }

  Future<List<SearchResult>> getRecommendations({
    String userId = 'anonymous',
    int limit = 5,
  }) async {
    try {
      final uri = Uri.parse(
          '$baseUrl/api/recommendations?user_id=$userId&limit=$limit');
      debugPrint('[Recommendation] GET $uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 30));

      debugPrint('[Recommendation] status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (data['results'] ?? []) as List;
        return list
            .map((p) => SearchResult.fromJson(p as Map<String, dynamic>))
            .toList();
      }
      debugPrint('[Recommendation] error body: ${response.body}');
      return [];
    } catch (e) {
      debugPrint('[Recommendation] getRecommendations exception: $e');
      return [];
    }
  }
}
