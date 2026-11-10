import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import '../utils/app_constants.dart';

/// Global background service that tracks app usage time, sending heartbeats
/// to the backend every minute and when the app changes lifecycle state.
class SessionTrackerService with WidgetsBindingObserver {
  static final SessionTrackerService _instance = SessionTrackerService._internal();
  factory SessionTrackerService() => _instance;
  static SessionTrackerService get instance => _instance;
  SessionTrackerService._internal();

  Timer? _heartbeatTimer;
  DateTime? _lastTick;
  bool _isRunning = false;

  /// Starts the tracking session. Safe to call multiple times.
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _lastTick = DateTime.now();
    WidgetsBinding.instance.addObserver(this);

    // Heartbeat every 60 seconds
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      flushHeartbeat();
    });
  }

  /// Stops tracking and flushes remaining seconds.
  void stop() {
    flushHeartbeat();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isRunning = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Calculates elapsed seconds since last tick and sends a heartbeat to backend.
  Future<void> flushHeartbeat() async {
    final now = DateTime.now();
    if (_lastTick == null) {
      _lastTick = now;
      return;
    }

    final elapsedSeconds = now.difference(_lastTick!).inSeconds;
    _lastTick = now;

    if (elapsedSeconds <= 0) return;

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final email = user?.email;

    try {
      final uri = Uri.parse('${AppConstants.researchBaseUrl}/users/heartbeat');
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'seconds_spent': elapsedSeconds,
          if (uid != null && uid.isNotEmpty) 'user_id': uid,
          if (email != null && email.isNotEmpty) 'email': email,
        }),
      );
    } catch (_) {
      // Silent in background — user experience should never be interrupted
    }
  }

  /// Fetches real profile stats (total hours, streak, active dates, papers read).
  Future<Map<String, dynamic>?> fetchProfileStats() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final email = user?.email;

    try {
      final queryParams = <String, String>{};
      if (uid != null && uid.isNotEmpty) queryParams['user_id'] = uid;
      if (email != null && email.isNotEmpty) queryParams['email'] = email;

      final uri = Uri.parse('${AppConstants.researchBaseUrl}/users/profile-stats').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {
      // Network/offline error fallback handled gracefully
    }
    return null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      flushHeartbeat();
    } else if (state == AppLifecycleState.resumed) {
      _lastTick = DateTime.now();
    }
  }
}
