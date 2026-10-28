import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class UsageService {
  static const String _endpoint =
      'http://localhost:8001/api/admin/usage/record';

  /// Records an aggregated usage event for the current logged-in student.
  /// Fire-and-forget: does not block the UI and silently catches any errors.
  static void recordEvent(String eventType) {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email;
      if (email == null || email.trim().isEmpty) {
        debugPrint('[UsageService] No user email found for event: $eventType');
        return;
      }

      final uri = Uri.parse(_endpoint);
      final body = jsonEncode({
        'student_email': email.trim().toLowerCase(),
        'student_external_uid': user?.uid,
        'event_type': eventType,
      });

      http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 5))
          .catchError((e) {
        debugPrint('[UsageService] Failed to record event $eventType: $e');
        return http.Response('', 500);
      });
    } catch (e) {
      debugPrint('[UsageService] Error recording event $eventType: $e');
    }
  }
}
