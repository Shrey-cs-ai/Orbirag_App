import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/app_constants.dart';
import 'auth_service.dart';

class AdminService {
  String get _baseUrl => AppConstants.researchBaseUrl;
  final AuthService _auth = AuthService();

  Future<List<AuthUser>> listUsers({String? search}) async {
    final uri = Uri.parse('$_baseUrl/admin/users').replace(
      queryParameters: (search != null && search.isNotEmpty)
          ? {'search': search}
          : null,
    );
    final response = await http.get(uri, headers: _auth.authHeaders);
    if (response.statusCode != 200) {
      throw Exception('Failed to load users: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['items'] as List)
        .map((e) => AuthUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> banUser(String id) async {
    final r = await http.patch(
      Uri.parse('$_baseUrl/admin/users/$id/ban'),
      headers: _auth.authHeaders,
    );
    if (r.statusCode != 200) throw Exception('Ban failed');
  }

  Future<void> unbanUser(String id) async {
    final r = await http.patch(
      Uri.parse('$_baseUrl/admin/users/$id/unban'),
      headers: _auth.authHeaders,
    );
    if (r.statusCode != 200) throw Exception('Unban failed');
  }

  Future<void> setRole(String id, String role) async {
    final r = await http.patch(
      Uri.parse('$_baseUrl/admin/users/$id/role?role=$role'),
      headers: _auth.authHeaders,
    );
    if (r.statusCode != 200) throw Exception('Role change failed');
  }

  Future<void> resetPassword(String id, String newPassword) async {
    final r = await http.patch(
      Uri.parse('$_baseUrl/admin/users/$id/password'),
      headers: _auth.authHeaders,
      body: jsonEncode({'new_password': newPassword}),
    );
    if (r.statusCode != 200) throw Exception('Password reset failed');
  }

  Future<void> deleteUser(String id) async {
    final r = await http.delete(
      Uri.parse('$_baseUrl/admin/users/$id'),
      headers: _auth.authHeaders,
    );
    if (r.statusCode != 200) throw Exception('Delete failed');
  }

  Future<AuthUser> createUser({
    required String username,
    required String password,
    String? email,
    String role = 'user',
  }) async {
    final r = await http.post(
      Uri.parse('$_baseUrl/admin/users'),
      headers: _auth.authHeaders,
      body: jsonEncode({
        'username': username,
        'password': password,
        'email': email,
        'role': role,
      }),
    );
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw Exception('Create user failed: ${r.statusCode}');
    }
    return AuthUser.fromJson(jsonDecode(r.body));
  }
}