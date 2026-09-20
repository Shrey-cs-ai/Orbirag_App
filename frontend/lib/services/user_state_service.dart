import 'package:shared_preferences/shared_preferences.dart';

class UserStateService {
  static final UserStateService _instance = UserStateService._internal();
  factory UserStateService() => _instance;
  UserStateService._internal();

  static const String _keyHasStartedResearch = 'has_started_research';
  static const String _keyFirstName = 'user_first_name';

  /// Check if user has already started their first research
  Future<bool> hasStartedResearch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasStartedResearch) ?? false;
  }

  /// Mark that user has started research
  Future<void> setHasStartedResearch(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasStartedResearch, value);
  }

  /// Save user's first name for greeting
  Future<void> saveFirstName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFirstName, name);
  }

  /// Get user's first name
  Future<String> getFirstName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFirstName) ?? 'Researcher';
  }

  /// Reset user state (for testing)
  Future<void> resetUserState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasStartedResearch, false);
  }
}