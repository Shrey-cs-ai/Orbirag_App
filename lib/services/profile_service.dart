import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  // ==================== ROLE ====================
  Future<void> saveRole(String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', role);
    } catch (e) {
      debugPrint('Error saving role: $e');
    }
  }

  Future<String?> getRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_role');
    } catch (e) {
      debugPrint('Error getting role: $e');
      return null;
    }
  }

  // ==================== PROGRESS ====================
  Future<void> saveProgress(Map<String, dynamic> progress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_progress', jsonEncode(progress));
    } catch (e) {
      debugPrint('Error saving progress: $e');
    }
  }

  Future<Map<String, dynamic>?> getProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('user_progress');
      if (json != null) {
        return jsonDecode(json) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error getting progress: $e');
    }
    return null;
  }

  // ==================== NOTIFICATIONS ====================
  Future<void> saveNotifications(List<Map<String, dynamic>> notifications) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notifications', jsonEncode(notifications));
    } catch (e) {
      debugPrint('Error saving notifications: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('notifications');
      if (json != null) {
        final List<dynamic> decoded = jsonDecode(json);
        return decoded.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (e) {
      debugPrint('Error getting notifications: $e');
    }
    return [];
  }

  // ==================== PROFILE PIC ====================
  Future<void> saveProfilePicPath(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_pic_path', path);
    } catch (e) {
      debugPrint('Error saving profile pic: $e');
    }
  }

  Future<String?> getProfilePicPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('profile_pic_path');
    } catch (e) {
      debugPrint('Error getting profile pic: $e');
      return null;
    }
  }
}