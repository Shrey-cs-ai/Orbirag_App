import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

/// Unified usage-tracking service.
///
/// Exposes both a singleton instance API and a static fire-and-forget method
/// so all existing callers (instance or static) continue to work.
class UsageService {
  static final UsageService _instance = UsageService._internal();
  factory UsageService() => _instance;
  UsageService._internal();

  static const String _endpoint =
      'http://localhost:8001/api/admin/usage/record';

  // ── Instance API (used by paper_reader_screen, etc.) ──────
  /// Record a named usage event. Also POSTs to the admin usage endpoint.
  Future<void> recordEvent(String event,
      {Map<String, dynamic>? extra}) async {
    debugPrint('[UsageService] event=$event extra=$extra');
    _postToBackend(event);
  }

  // ── Static API (used by admin_dashboard and screens that call static) ─
  /// Fire-and-forget static method. Posts to backend with Firebase user info.
  static void recordEventStatic(String eventType) {
    _postToBackend(eventType);
  }

  static void _postToBackend(String eventType) {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email;
      if (email == null || email.trim().isEmpty) {
        debugPrint(
            '[UsageService] No user email found for event: $eventType');
        return;
      }

      final uri = Uri.parse(_endpoint);
      final body = jsonEncode({
        'student_email': email.trim().toLowerCase(),
        'student_external_uid': user?.uid,
        'event_type': eventType,
      });

      http
          .post(uri,
              headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 5))
          .catchError((e) {
        debugPrint(
            '[UsageService] Failed to record event $eventType: $e');
        return http.Response('', 500);
      });
    } catch (e) {
      debugPrint('[UsageService] Error recording event $eventType: $e');
    }
  }
}
