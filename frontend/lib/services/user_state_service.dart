import 'package:shared_preferences/shared_preferences.dart';

class UserStateService {
  static final UserStateService _instance = UserStateService._internal();
  factory UserStateService() => _instance;
  UserStateService._internal();

  static const String _keyHasStartedResearch = 'has_started_research';
  static const String _keyFirstName = 'user_first_name';
  static const String _keyLastResearchTopic = 'last_research_topic';
  static const String _keyLastResearchProgress = 'last_research_progress';
  static const String _keyLastResearchTime = 'last_research_time';

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

  /// Get last research topic
  Future<String?> getLastResearchTopic() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastResearchTopic);
  }

  /// Save last research topic
  Future<void> saveLastResearchTopic(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastResearchTopic, topic);
    await prefs.setString(
        _keyLastResearchTime, DateTime.now().toIso8601String());
  }

  /// Get last research progress
  Future<double?> getLastResearchProgress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyLastResearchProgress);
  }

  /// Save last research progress
  Future<void> saveLastResearchProgress(double progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLastResearchProgress, progress);
  }

  /// Get last research time
  Future<String?> getLastResearchTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastResearchTime);
  }

  /// Reset user state (for testing)
  Future<void> resetUserState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasStartedResearch, false);
    await prefs.remove(_keyLastResearchTopic);
    await prefs.remove(_keyLastResearchProgress);
    await prefs.remove(_keyLastResearchTime);
  }
}