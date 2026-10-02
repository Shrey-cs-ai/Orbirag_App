import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_constants.dart';

class AuthUser {
  final String id;
  final String username;
  final String? email;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLogin;

  AuthUser({
    required this.id,
    required this.username,
    this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.lastLogin,
  });

  bool get isAdmin => role == 'admin';

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'].toString(),
        username: json['username'] ?? '',
        email: json['email'],
        role: json['role'] ?? 'user',
        isActive: json['is_active'] ?? true,
        createdAt: DateTime.parse(json['created_at']).toLocal(),
        lastLogin: json['last_login'] != null
            ? DateTime.parse(json['last_login']).toLocal()
            : null,
      );
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final String _baseUrl = AppConstants.researchBaseUrl;
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  String? _token;
  AuthUser? _currentUser;

  String? get token => _token;
  AuthUser? get currentUser => _currentUser;
  bool get isLoggedIn => _token != null && _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      _currentUser = AuthUser.fromJson(jsonDecode(userJson));
    }
  }

  Future<AuthUser> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Login failed');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _token = data['access_token'];
    _currentUser = AuthUser.fromJson(data['user']);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, _token!);
    await prefs.setString(_userKey, jsonEncode(data['user']));

    return _currentUser!;
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<void> refreshMe() async {
    if (_token == null) return;
    final response = await http.get(
      Uri.parse('$_baseUrl/auth/me'),
      headers: authHeaders,
    );
    if (response.statusCode == 200) {
      _currentUser = AuthUser.fromJson(jsonDecode(response.body));
    }
  }
}