import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

/// Unified usage-tracking service.
///
/// Exposes a static fire-and-forget method for usage-event tracking.
class UsageService {
  static final UsageService _instance = UsageService._internal();
  factory UsageService() => _instance;
  UsageService._internal();

  static const String _endpoint =
      'http://localhost:8001/api/admin/usage/record';

  /// Records an aggregated usage event for the current logged-in student.
  /// Fire-and-forget: does not block the UI and logs any errors.
  static Future<void> recordEvent(String eventType,
      {Map<String, dynamic>? extra}) async {
    debugPrint('[UsageService] event=$eventType extra=$extra');
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

  // Also support static alias if needed
  static void recordEventStatic(String eventType) {
    recordEvent(eventType);
  }
}
