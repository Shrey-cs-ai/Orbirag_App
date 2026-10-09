import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import 'admin_login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _admin = AdminService();
  final _auth = AuthService();
  final _search = TextEditingController();

  List<AuthUser> _users = [];
  bool _loading = true;
  String? _error;
  String _roleFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var users = await _admin.listUsers(search: _search.text.trim());
      if (_roleFilter == 'admin') {
        users = users.where((u) => u.isAdmin).toList();
      } else if (_roleFilter == 'user') {
        users = users.where((u) => !u.isAdmin).toList();
      }
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
    );
  }

  void _setRoleFilter(String role) {
    setState(() => _roleFilter = role);
    _load();
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  void _showUserDetails(AuthUser user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: user.isAdmin
                    ? AppColors.purple.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.2),
                backgroundImage: user.avatarBase64 != null &&
                        user.avatarBase64!.isNotEmpty
                    ? MemoryImage(base64Decode(user.avatarBase64!))
                    : null,
                child: (user.avatarBase64 == null ||
                        user.avatarBase64!.isEmpty)
                    ? Icon(
                        user.isAdmin ? Icons.shield : Icons.person,
                        size: 40,
                        color: user.isAdmin
                            ? AppColors.purple
                            : AppColors.primary,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                user.username,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            _row('Email', user.email ?? '—'),
            _row('Role', user.role),
            _row('Status', user.isActive ? 'Active' : 'Banned'),
            _row('Created', user.createdAt.toString().split('.').first),
            _row('Last login',
                user.lastLogin?.toString().split('.').first ?? 'Never'),
            const SizedBox(height: 8),
            const Text(
              'Passwords are hashed and cannot be viewed.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final controller = TextEditingController();
                      final newPassword = await showDialog<String>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Reset password'),
                          content: TextField(
                            controller: controller,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'New password',
                              hintText: 'Min 6 characters',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                final pwd = controller.text.trim();
                                if (pwd.length < 6) return;
                                Navigator.pop(context, pwd);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Reset'),
                            ),
                          ],
                        ),
                      );

                      if (newPassword == null || newPassword.isEmpty) {
                        return;
                      }

                      try {
                        await _admin.resetPassword(user.id, newPassword);
                        if (!mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Password reset for ${user.username}'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Reset failed: $e'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.key),
                    label: const Text('Reset password'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.error),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _filterChip('All', _roleFilter == 'all',
                        () => _setRoleFilter('all')),
                    const SizedBox(width: 8),
                    _filterChip('Admins', _roleFilter == 'admin',
                        () => _setRoleFilter('admin')),
                    const SizedBox(width: 8),
                    _filterChip('Users', _roleFilter == 'user',
                        () => _setRoleFilter('user')),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  onChanged: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _users.isEmpty
                        ? const Center(child: Text('No users found'))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _users.length,
                              itemBuilder: (_, i) => _userCard(_users[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _userCard(AuthUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: user.isAdmin
                    ? AppColors.purple.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.2),
                backgroundImage: user.avatarBase64 != null &&
                        user.avatarBase64!.isNotEmpty
                    ? MemoryImage(base64Decode(user.avatarBase64!))
                    : null,
                child: (user.avatarBase64 == null ||
                        user.avatarBase64!.isEmpty)
                    ? Icon(
                        user.isAdmin ? Icons.shield : Icons.person,
                        color: user.isAdmin
                            ? AppColors.purple
                            : AppColors.primary,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.username,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    Text(user.email ?? 'no email',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: user.isActive
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  user.isActive ? 'ACTIVE' : 'BANNED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: user.isActive
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _showUserDetails(user),
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('Details'),
              ),
              TextButton.icon(
                onPressed: () async {
                  if (user.isActive) {
                    await _admin.banUser(user.id);
                  } else {
                    await _admin.unbanUser(user.id);
                  }
                  _load();
                },
                icon: Icon(
                  user.isActive ? Icons.block : Icons.check_circle,
                  size: 16,
                ),
                label: Text(user.isActive ? 'Ban' : 'Unban'),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.error, size: 20),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete Profile'),
                      content: Text(
                          'Permanently delete "${user.username}"? This also removes their avatar and cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    try {
                      await _admin.deleteUser(user.id);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Deleted ${user.username}'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                      _load();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Delete failed: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}