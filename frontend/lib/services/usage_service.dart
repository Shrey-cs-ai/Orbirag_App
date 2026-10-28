import 'package:flutter/foundation.dart' show debugPrint;

/// Lightweight event-tracking service.
/// Extend later to POST events to a backend analytics endpoint.
class UsageService {
  static final UsageService _instance = UsageService._internal();
  factory UsageService() => _instance;
  UsageService._internal();

  /// Record a named usage event.
  /// Currently logs to debug output; swap body for HTTP POST when ready.
  Future<void> recordEvent(String event, {Map<String, dynamic>? extra}) async {
    debugPrint('[UsageService] event=$event extra=$extra');
    // TODO: POST to analytics endpoint when available.
  }
}

