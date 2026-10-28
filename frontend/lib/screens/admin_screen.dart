// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/admin/activity_tile.dart';
import '../widgets/admin/dashboard_skeleton.dart';
import '../widgets/admin/license_usage_card.dart';
import '../widgets/admin/stat_card.dart';
import '../widgets/admin/trend_card.dart';

// ============================================================
// API Client
// ============================================================
class AdminApi {
  static const _base = 'http://localhost:8001';
  static String? _token;

  static String? get token => _token;

  static Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body,
      {bool auth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth && _token != null) headers['Authorization'] = 'Bearer $_token';
    final r = await http.post(Uri.parse('$_base$path'),
        headers: headers, body: jsonEncode(body));
    if (r.statusCode >= 400) throw Exception('HTTP ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<dynamic> _get(String path) async {
    final headers = <String, String>{};
    if (_token != null) headers['Authorization'] = 'Bearer $_token';
    final r = await http.get(Uri.parse('$_base$path'), headers: headers);
    if (r.statusCode >= 400) throw Exception('HTTP ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body);
  }

  static Future<Map<String, dynamic>> _patch(
      String path, Map<String, dynamic> body) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_token != null) headers['Authorization'] = 'Bearer $_token';
    final r = await http.patch(Uri.parse('$_base$path'),
        headers: headers, body: jsonEncode(body));
    if (r.statusCode >= 400) throw Exception('HTTP ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // --- endpoints ---
  static Future<void> login(String email, String password) async {
    final res = await _post(
        '/api/admin/auth/login', {'email': email, 'password': password},
        auth: false);
    _token = res['token'] as String;
  }

  static void logout() => _token = null;

  static Future<Map<String, dynamic>> summary() async =>
      await _get('/api/admin/dashboard/summary') as Map<String, dynamic>;
  static Future<Map<String, dynamic>> institution() async =>
      await _get('/api/admin/institution') as Map<String, dynamic>;
  static Future<Map<String, dynamic>> students(
      {String? search, String? status, int page = 1}) async {
    final qs = <String>['page=$page', 'page_size=20'];
    if (search != null && search.isNotEmpty)
      qs.add('search=${Uri.encodeComponent(search)}');
    if (status != null) qs.add('status=$status');
    return await _get('/api/admin/students?${qs.join('&')}')
        as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> student(int id) async =>
      await _get('/api/admin/students/$id') as Map<String, dynamic>;
  static Future<Map<String, dynamic>> changeStatus(int id, String status,
          {String? reason, int? days}) =>
      _patch('/api/admin/students/$id/status', {
        'status': status,
        if (reason != null) 'reason': reason,
        if (days != null) 'suspend_days': days,
      });
  static Future<Map<String, dynamic>> resetPassword(int id) =>
      _post('/api/admin/students/$id/reset-password', {});
  static Future<Map<String, dynamic>> features() async =>
      await _get('/api/admin/analytics/features') as Map<String, dynamic>;
  static Future<List<dynamic>> getRecentLogins() async =>
      await _get('/api/admin/logins/recent') as List<dynamic>;
  static Future<List<dynamic>> audit() async =>
      await _get('/api/admin/audit-logs') as List<dynamic>;
}

// ============================================================
// Entry Screen
// ============================================================
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _loggedIn = false;

  @override
  Widget build(BuildContext context) {
    if (!_loggedIn) {
      return _LoginView(onLogin: () => setState(() => _loggedIn = true));
    }
    return _DashboardView(onLogout: () {
      AdminApi.logout();
      setState(() => _loggedIn = false);
    });
  }
}

// ============================================================
// Login View
// ============================================================
class _LoginView extends StatefulWidget {
  final VoidCallback onLogin;
  const _LoginView({required this.onLogin});
  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _email = TextEditingController(text: 'admin@orbirag.local');
  final _password = TextEditingController(text: 'admin123');
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await AdminApi.login(_email.text.trim(), _password.text);
      widget.onLogin();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Login failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Portal')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.admin_panel_settings,
                      size: 56, color: AppColors.primary),
                  const SizedBox(height: 12),
                  const Text('Campus Admin Dashboard',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _email,
                    decoration: const InputDecoration(
                      labelText: 'Admin email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Sign In'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Demo: admin@orbirag.local / admin123',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Dashboard View — 5 tabs
// ============================================================
class _DashboardView extends StatefulWidget {
  final VoidCallback onLogout;
  const _DashboardView({required this.onLogout});
  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 6, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Orbirag Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: widget.onLogout,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Dashboard'),
            Tab(icon: Icon(Icons.people_outline), text: 'Students'),
            Tab(icon: Icon(Icons.insights_outlined), text: 'Analytics'),
            Tab(icon: Icon(Icons.login), text: 'Logins'),
            Tab(icon: Icon(Icons.privacy_tip_outlined), text: 'Privacy'),
            Tab(icon: Icon(Icons.history), text: 'Audit'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _DashboardTab(),
          _StudentsTab(),
          _AnalyticsTab(),
          _LoginsTab(),
          _PrivacyTab(),
          _AuditTab(),
        ],
      ),
    );
  }
}

// ============================================================
// Tab 1 — Dashboard
// ============================================================
class _DashboardTab extends StatefulWidget {
  const _DashboardTab();
  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _inst;
  List<dynamic> _auditLogs = [];
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final s = await AdminApi.summary();
      final i = await AdminApi.institution();
      List<dynamic> a = [];
      try {
        a = await AdminApi.audit();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _summary = s;
        _inst = i;
        _auditLogs = a;
        _loading = false;
        _err = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _err = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_err != null) {
      return ColoredBox(
        color: AppColors.background,
        child: _buildErrorView(),
      );
    }

    if (_loading || _summary == null || _inst == null) {
      return const ColoredBox(
        color: AppColors.background,
        child: DashboardSkeleton(),
      );
    }

    return ColoredBox(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        backgroundColor: AppColors.cardBg,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Header
            _buildHeader(),
            const SizedBox(height: 16),

            // 2. License Usage Card
            LicenseUsageCard(
              used: (_inst!['used'] as num?)?.toInt() ?? 0,
              limit: (_inst!['license_limit'] as num?)?.toInt() ?? 0,
            ),
            const SizedBox(height: 16),

            // 3. Row of two smaller cards (Active Students & Renewal)
            _buildStatCardsRow(),
            const SizedBox(height: 16),

            // 4. Research Activity Card
            _buildResearchActivityCard(),
            const SizedBox(height: 16),

            // 5. Trend Card
            TrendCard(
              activeThisWeek:
                  (_summary!['active_this_week'] as num?)?.toInt() ?? 0,
              totalActive: (_summary!['active_students'] as num?)?.toInt(),
            ),

            // 6. Needs attention strip
            _buildNeedsAttentionSection(),

            // 7. Quick actions row
            _buildQuickActionsRow(),
            const SizedBox(height: 16),

            // 8. Recent Admin Activity
            _buildRecentActivityCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load dashboard',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _err ?? 'An unexpected error occurred.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(
                'Retry',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final institutionName = (_inst?['name'] ?? '').toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Good morning, Admin',
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (institutionName.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.apartment,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: Text(
                        institutionName,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Here's your Orbirag campus overview",
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCardsRow() {
    final activeStudents =
        (_summary?['active_students'] as num?)?.toInt() ?? 0;
    final planRaw = (_inst?['plan'] ?? 'Standard').toString();
    final planDisplayName = planRaw
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');

    final renewalDateStr = _inst?['renewal_date']?.toString();
    DateTime? renewalDate;
    if (renewalDateStr != null && renewalDateStr.isNotEmpty) {
      renewalDate = DateTime.tryParse(renewalDateStr);
    }
    final int daysLeft = renewalDate != null
        ? renewalDate.difference(DateTime.now()).inDays
        : 0;

    final renewalDateFormatted = renewalDate != null
        ? '${renewalDate.year}-${renewalDate.month.toString().padLeft(2, '0')}-${renewalDate.day.toString().padLeft(2, '0')}'
        : 'N/A';
    final renewalHelper = renewalDate != null
        ? 'Renews: $renewalDateFormatted'
        : 'No renewal date';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: StatCard(
              title: 'Active Students',
              value: '$activeStudents',
              helperText: 'Used Orbirag in the last 30 days',
              icon: Icons.people_outline,
              iconColor: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              title: 'Renewal',
              value: planDisplayName,
              helperText: renewalHelper,
              badgeText: renewalDate != null ? '$daysLeft days left' : null,
              badgeColor:
                  daysLeft < 60 ? AppColors.warning : AppColors.success,
              icon: Icons.calendar_today_outlined,
              iconColor: AppColors.oriColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResearchActivityCard() {
    final litSearches = ((_summary?['literature_search'] ??
            _summary?['papers_analyzed']) as num?)
            ?.toInt() ??
        0;
    final gapAnalyses = ((_summary?['gap_analysis'] ??
            _summary?['gap_analyses']) as num?)
            ?.toInt() ??
        0;
    final citationChecks = ((_summary?['citation_checks'] ??
            _summary?['ai_citation_checks']) as num?)
            ?.toInt() ??
        0;
    final totalActions = litSearches + gapAnalyses + citationChecks;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Research Activity',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$totalActions total actions',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildActivityRow(
            icon: Icons.menu_book_outlined,
            iconColor: AppColors.primary,
            label: 'Literature searches',
            count: litSearches,
          ),
          const Divider(color: AppColors.border, height: 16),
          _buildActivityRow(
            icon: Icons.insights_outlined,
            iconColor: AppColors.oriColor,
            label: 'Gap analyses',
            count: gapAnalyses,
          ),
          const Divider(color: AppColors.border, height: 16),
          _buildActivityRow(
            icon: Icons.fact_check_outlined,
            iconColor: AppColors.success,
            label: 'Citation checks',
            count: citationChecks,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required int count,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          '$count',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildNeedsAttentionSection() {
    final used = (_inst?['used'] as num?)?.toInt() ?? 0;
    final limit = (_inst?['license_limit'] as num?)?.toInt() ?? 0;
    final ratio = limit > 0 ? (used / limit) : 0.0;
    final usagePercent = ratio * 100.0;

    final renewalDateStr = _inst?['renewal_date']?.toString();
    DateTime? renewalDate;
    if (renewalDateStr != null && renewalDateStr.isNotEmpty) {
      renewalDate = DateTime.tryParse(renewalDateStr);
    }
    final int daysLeft = renewalDate != null
        ? renewalDate.difference(DateTime.now()).inDays
        : 999;

    final isHighUsage = usagePercent > 90.0;
    final isRenewalClose = renewalDate != null && daysLeft < 60;

    if (!isHighUsage && !isRenewalClose) {
      return const SizedBox.shrink();
    }

    final String message;
    if (isHighUsage && isRenewalClose) {
      message =
          'High license usage (${usagePercent.toStringAsFixed(0)}%) and renewal due in $daysLeft days.';
    } else if (isHighUsage) {
      message =
          'High license usage: ${usagePercent.toStringAsFixed(0)}% of seats are currently in use.';
    } else {
      message =
          'Campus renewal is approaching: $daysLeft days remaining on your plan.';
    }

    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Needs Attention',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildQuickActionButton(
            icon: Icons.person_add_outlined,
            label: 'Add students',
            onTap: () => _showQuickActionSnackBar('Add students'),
          ),
          const SizedBox(width: 10),
          _buildQuickActionButton(
            icon: Icons.upload_file_outlined,
            label: 'Bulk upload',
            onTap: () => _showQuickActionSnackBar('Bulk upload'),
          ),
          const SizedBox(width: 10),
          _buildQuickActionButton(
            icon: Icons.mail_outline,
            label: 'Send invite',
            onTap: () => _showQuickActionSnackBar('Send invite'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: AppColors.primary),
      label: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.cardBg,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showQuickActionSnackBar(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$action action clicked',
          style: GoogleFonts.inter(color: AppColors.cardBg),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    final recentLogs = _auditLogs.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Admin Activity',
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (recentLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No recent admin activity recorded.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ...recentLogs.asMap().entries.map((entry) {
              final index = entry.key;
              final log = entry.value as Map<String, dynamic>;
              final action = (log['action'] ?? '').toString();

              final IconData icon;
              final Color iconColor;
              if (action.contains('ban') && !action.contains('unban')) {
                icon = Icons.block;
                iconColor = AppColors.error;
              } else if (action.contains('unban')) {
                icon = Icons.check_circle_outline;
                iconColor = AppColors.success;
              } else if (action.contains('login')) {
                icon = Icons.login;
                iconColor = AppColors.primary;
              } else if (action.contains('logout')) {
                icon = Icons.logout;
                iconColor = AppColors.textSecondary;
              } else if (action.contains('reset')) {
                icon = Icons.lock_reset;
                iconColor = AppColors.warning;
              } else {
                icon = Icons.history;
                iconColor = AppColors.oriColor;
              }

              final title = action
                  .replaceAll('_', ' ')
                  .split(' ')
                  .map((w) =>
                      w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
                  .join(' ');

              String? subtitle;
              final targetStudentId = log['target_student_id'];
              final details = log['details']?.toString();
              if (targetStudentId != null &&
                  details != null &&
                  details.isNotEmpty) {
                subtitle = 'Student #$targetStudentId · $details';
              } else if (targetStudentId != null) {
                subtitle = 'Student #$targetStudentId';
              } else if (details != null && details.isNotEmpty) {
                subtitle = details;
              }

              final createdAtStr = log['created_at']?.toString();
              final time = _formatLogTime(createdAtStr);

              return Column(
                children: [
                  if (index > 0)
                    const Divider(color: AppColors.border, height: 12),
                  ActivityTile(
                    icon: icon,
                    iconColor: iconColor,
                    title: title,
                    subtitle: subtitle,
                    time: time,
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  String _formatLogTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) {
      return dateStr.length > 10 ? dateStr.substring(0, 10) : dateStr;
    }
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }
}


// ============================================================
// Tab 2 — Students
// ============================================================
class _StudentsTab extends StatefulWidget {
  const _StudentsTab();
  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<_StudentsTab> {
  final _search = TextEditingController();
  String? _statusFilter;
  List<dynamic> _items = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await AdminApi.students(
          search: _search.text.trim(), status: _statusFilter);
      if (!mounted) return;
      setState(() => _items = r['items'] as List<dynamic>);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Search by name or email',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String?>(
            value: _statusFilter,
            hint: const Text('All'),
            items: const [
              DropdownMenuItem(value: null, child: Text('All')),
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
              DropdownMenuItem(value: 'banned', child: Text('Banned')),
            ],
            onChanged: (v) {
              setState(() => _statusFilter = v);
              _load();
            },
          ),
        ]),
      ),
      if (_loading) const LinearProgressIndicator(),
      Expanded(
        child: _items.isEmpty && !_loading
            ? const Center(child: Text('No students'))
            : ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = _items[i];
                  final statusColor = s['status'] == 'active'
                      ? Colors.green
                      : s['status'] == 'suspended'
                          ? Colors.orange
                          : Colors.red;
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text((s['name'] ?? '?')
                          .toString()
                          .characters
                          .first
                          .toUpperCase()),
                    ),
                    title: Text(s['name'] ?? ''),
                    subtitle: Text(s['email'] ?? '',
                        style: const TextStyle(fontSize: 12)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${s['status']}'.toUpperCase(),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor)),
                    ),
                    onTap: () => _openStudent(s['id'] as int),
                  );
                },
              ),
      ),
    ]);
  }

  Future<void> _openStudent(int id) async {
    final detail = await AdminApi.student(id);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StudentProfileSheet(detail: detail, onChanged: _load),
    );
  }
}

class _StudentProfileSheet extends StatelessWidget {
  final Map<String, dynamic> detail;
  final VoidCallback onChanged;
  const _StudentProfileSheet({required this.detail, required this.onChanged});

  Future<void> _changeStatus(BuildContext ctx, int id, String status,
      {String? reason}) async {
    try {
      await AdminApi.changeStatus(id, status, reason: reason);
      if (ctx.mounted) Navigator.pop(ctx);
      onChanged();
    } catch (e) {
      if (ctx.mounted)
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = detail['student'] as Map<String, dynamic>;
    final u = detail['usage'] as Map<String, dynamic>;
    final counts = u['counts'] as Map<String, dynamic>? ?? {};
    final statusColor = s['status'] == 'active'
        ? Colors.green
        : s['status'] == 'suspended'
            ? Colors.orange
            : Colors.red;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: CircleAvatar(
                      radius: 32,
                      child: Text(
                          (s['name'] ?? '?')
                              .toString()
                              .characters
                              .first
                              .toUpperCase(),
                          style: const TextStyle(fontSize: 24)))),
              const SizedBox(height: 8),
              Center(
                  child: Text(s['name'] ?? '',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold))),
              Center(
                  child: Text(s['email'] ?? '',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey))),
              const SizedBox(height: 8),
              Center(
                  child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('${s['status']}'.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor)),
              )),
              const Divider(height: 32),
              _row('Joined',
                  s['created_at']?.toString().substring(0, 10) ?? '—'),
              _row('Last active',
                  s['last_active_at']?.toString().substring(0, 10) ?? '—'),
              if (s['ban_reason'] != null) _row('Reason', s['ban_reason']),
              const Divider(height: 32),
              const Text('Usage summary (aggregated only)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _chip('Gap analyses', counts['gap_analysis'] ?? 0),
                _chip('Citations', counts['citation_check'] ?? 0),
                _chip('Plagiarism', counts['plagiarism_check'] ?? 0),
                _chip('Papers', counts['paper_analysis'] ?? 0),
              ]),
              const SizedBox(height: 4),
              const Text('Research content is not visible to admins.',
                  style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Colors.black54)),
              const Divider(height: 32),
              const Text('Actions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await AdminApi.resetPassword(s['id'] as int);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content:
                                Text('Reset email queued for ${s['email']}')));
                      }
                    } catch (e) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('$e')));
                    }
                  },
                  icon: const Icon(Icons.lock_reset, size: 16),
                  label: const Text('Send reset email'),
                ),
                if (s['status'] != 'active')
                  ElevatedButton.icon(
                    onPressed: () => _changeStatus(context, s['id'], 'active'),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Activate'),
                  ),
                if (s['status'] == 'active') ...[
                  OutlinedButton.icon(
                    onPressed: () => _changeStatus(
                        context, s['id'], 'suspended',
                        reason: 'Temporary suspension'),
                    icon: const Icon(Icons.pause, size: 16),
                    label: const Text('Suspend (7d)'),
                  ),
                  OutlinedButton.icon(
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => _changeStatus(context, s['id'], 'banned',
                        reason: 'Policy violation'),
                    icon: const Icon(Icons.block, size: 16),
                    label: const Text('Ban'),
                  ),
                ],
              ]),
            ]),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(
              width: 100,
              child: Text(k,
                  style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12))),
        ]),
      );

  Widget _chip(String label, dynamic count) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$label: $count', style: const TextStyle(fontSize: 11)),
      );
}

// ============================================================
// Tab 3 — Analytics
// ============================================================
class _FeatureCategory {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> featureKeys;

  const _FeatureCategory({
    required this.title,
    required this.icon,
    required this.color,
    required this.featureKeys,
  });
}

class _AnalyticsTab extends StatefulWidget {
  const _AnalyticsTab();
  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> {
  Map<String, dynamic>? _features;
  String? _err;

  static const List<_FeatureCategory> _categories = [
    _FeatureCategory(
      title: 'Research & Discovery',
      icon: Icons.explore_outlined,
      color: Color(0xFF2E5B88),
      featureKeys: [
        'topic_scoping',
        'literature_retrieval',
        'gap_analysis',
      ],
    ),
    _FeatureCategory(
      title: 'Reading & AI Assistance',
      icon: Icons.auto_awesome_outlined,
      color: AppColors.purple,
      featureKeys: [
        'paper_analysis',
        'paper_orbit',
        'ori_chatbot',
      ],
    ),
    _FeatureCategory(
      title: 'Writing & Integrity',
      icon: Icons.edit_note_rounded,
      color: AppColors.coral,
      featureKeys: [
        'methodology_builder',
        'citation_generation',
        'plagiarism_check',
        'word_counter',
        'notes_writing',
      ],
    ),
    _FeatureCategory(
      title: 'Organization',
      icon: Icons.folder_outlined,
      color: AppColors.sageDark,
      featureKeys: [
        'paper_saved',
        'library_access',
      ],
    ),
  ];

  static const Map<String, String> _featureNames = {
    'topic_scoping': 'Topic Scoping',
    'literature_retrieval': 'Literature Retrieval',
    'gap_analysis': 'Gap Analysis',
    'paper_analysis': 'Paper Analysis',
    'paper_orbit': 'Paper Orbit',
    'ori_chatbot': 'Ori Chatbot',
    'methodology_builder': 'Methodology Builder',
    'citation_generation': 'Citation Generation',
    'plagiarism_check': 'Plagiarism Check',
    'word_counter': 'Word Counter',
    'notes_writing': 'Notes Writing',
    'paper_saved': 'Paper Saved',
    'library_access': 'Library Access',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final f = await AdminApi.features();
      if (mounted) {
        setState(() {
          _features = f;
          _err = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _err = e.toString());
    }
  }

  String _formatStudents(num count) {
    final int val = count.toInt();
    final String str = val.toString();
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    final formatted = str.replaceAllMapped(reg, (match) => ',');
    return '$formatted ${val == 1 ? "student" : "students"}';
  }

  String _formatPercentage(num pct) {
    if (pct % 1 == 0) {
      return '${pct.toInt()}%';
    }
    return '${pct.toStringAsFixed(1)}%';
  }

  String _formatFeatureName(String key) {
    return _featureNames[key] ?? _humanize(key);
  }

  String _humanize(String key) => key
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  @override
  Widget build(BuildContext context) {
    if (_err != null) return Center(child: Text('Error: $_err'));
    if (_features == null)
      return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withOpacity(0.18)),
            ),
            child: const Row(
              children: [
                Icon(Icons.privacy_tip_outlined,
                    size: 18, color: AppColors.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Aggregated feature usage across the institution (Privacy-Safe)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final cat in _categories) _buildCategoryCard(cat),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(_FeatureCategory category) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.18)),
      ),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(category.icon, size: 18, color: category.color),
                ),
                const SizedBox(width: 10),
                Text(
                  category.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (int i = 0; i < category.featureKeys.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              _buildFeatureRow(category.featureKeys[i], category.color),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String key, Color accentColor) {
    final data = _features?[key] as Map<String, dynamic>?;
    final num pct = data != null ? (data['adoption_pct'] as num? ?? 0) : 0;
    final num users = data != null ? (data['unique_users'] as num? ?? 0) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _formatFeatureName(key),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              _formatPercentage(pct),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (pct / 100.0).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatStudents(users),
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Tab 3.5 — Logins
// ============================================================
class _LoginsTab extends StatefulWidget {
  const _LoginsTab();
  @override
  State<_LoginsTab> createState() => _LoginsTabState();
}

class _LoginsTabState extends State<_LoginsTab> {
  List<dynamic>? _logins;
  String? _err;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await AdminApi.getRecentLogins();
      if (mounted) {
        setState(() {
          _logins = list;
          _err = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _err = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _timeAgo(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '—';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return isoString;
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.isNegative || diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60)
      return '${diff.inMinutes} ${diff.inMinutes == 1 ? "min" : "mins"} ago';
    if (diff.inHours < 24)
      return '${diff.inHours} ${diff.inHours == 1 ? "hr" : "hrs"} ago';
    if (diff.inDays < 7)
      return '${diff.inDays} ${diff.inDays == 1 ? "day" : "days"} ago';
    return isoString.length >= 10 ? isoString.substring(0, 10) : isoString;
  }

  Widget _buildAvatar(String? photoUrl, String name) {
    final cleanName = name.trim();
    final initial = (cleanName.isNotEmpty ? cleanName[0] : '?').toUpperCase();
    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.primary.withOpacity(0.12),
        backgroundImage: NetworkImage(photoUrl.trim()),
        onBackgroundImageError: (_, __) {},
        child: Text(
          initial,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.primary.withOpacity(0.12),
      child: Text(
        initial,
        style: const TextStyle(
            fontWeight: FontWeight.bold, color: AppColors.primary),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    final r = role.toLowerCase();
    final isAdmin = r.contains('admin');
    final color = isAdmin ? AppColors.coral : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isSuccess = status.toLowerCase() == 'success';
    final color = isSuccess ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isSuccess ? 'Success' : 'Blocked',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isSuccess ? Colors.green.shade800 : Colors.red.shade800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _logins == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_err != null && _logins == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: $_err', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final items = _logins ?? [];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.isEmpty ? 1 : items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (items.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No login activity recorded yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          final log = items[index] as Map<String, dynamic>;
          final name = (log['student_name'] ?? 'Unknown').toString();
          final email = (log['email'] ?? '').toString();
          final role = (log['role'] ?? 'student').toString();
          final photoUrl = log['photo_url']?.toString();
          final time = log['login_time']?.toString();
          final status = (log['status'] ?? 'success').toString();

          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            leading: _buildAvatar(photoUrl, name),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildRoleBadge(role),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                email,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeAgo(time),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                _buildStatusBadge(status),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// Tab 4 — Privacy Center
// ============================================================
class _PrivacyTab extends StatelessWidget {
  const _PrivacyTab();

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(children: [
                  Icon(Icons.shield_outlined, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Student Privacy by Default',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
                SizedBox(height: 12),
                Text(
                  'Orbirag is built so that institutional control is separated from '
                  'student research. Admins manage access and view aggregated usage — '
                  'not the student\'s intellectual work.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ]),
        ),
      ),
      const SizedBox(height: 16),
      _section(context, 'Admins CAN access', Colors.green, [
        'Account information (name, email, role)',
        'Account status (active / suspended / banned)',
        'Aggregated usage counts per student',
        'Institution-wide analytics',
        'Audit logs of admin actions',
      ]),
      const SizedBox(height: 16),
      _section(context, 'Admins CANNOT access', Colors.red, [
        'Private research projects or topics',
        'Chat conversations with the AI',
        'AI prompts or responses',
        'Draft papers or uploaded PDFs',
        'Personal research notes',
        'Full plagiarism reports containing student text',
      ]),
      const SizedBox(height: 16),
      Card(
        color: Colors.amber.withOpacity(0.15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('AI-likelihood indicators',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text(
                  'If AI-likelihood indicators are ever surfaced to admins, they are '
                  'aggregated across the institution and clearly labelled as '
                  'AI-likelihood — not proof of misconduct.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ]),
        ),
      ),
    ]);
  }

  Widget _section(
          BuildContext ctx, String title, Color color, List<String> items) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 8),
            for (final i in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(title.contains('CANNOT') ? Icons.close : Icons.check,
                          color: color, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(i, style: const TextStyle(fontSize: 13))),
                    ]),
              ),
          ]),
        ),
      );
}

// ============================================================
// Tab 5 — Audit
// ============================================================
class _AuditTab extends StatefulWidget {
  const _AuditTab();
  @override
  State<_AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends State<_AuditTab> {
  List<dynamic>? _logs;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await AdminApi.audit();
      if (mounted)
        setState(() {
          _logs = r;
          _err = null;
        });
    } catch (e) {
      if (mounted) setState(() => _err = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_err != null) return Center(child: Text('Error: $_err'));
    if (_logs == null) return const Center(child: CircularProgressIndicator());
    if (_logs!.isEmpty)
      return const Center(child: Text('No audit entries yet'));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _logs!.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final l = _logs![i];
          final action = l['action']?.toString() ?? '';
          final icon = action.contains('ban')
              ? Icons.block
              : action.contains('login')
                  ? Icons.login
                  : action.contains('logout')
                      ? Icons.logout
                      : action.contains('reset')
                          ? Icons.lock_reset
                          : action.contains('unban')
                              ? Icons.check_circle
                              : Icons.history;
          final color = action.contains('ban')
              ? Colors.red
              : action.contains('unban') || action.contains('login')
                  ? Colors.green
                  : AppColors.primary;
          return ListTile(
            leading: Icon(icon, color: color),
            title: Text(action.replaceAll('_', ' ').toUpperCase(),
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(
                [
                  if (l['target_student_id'] != null)
                    'Student #${l['target_student_id']}',
                  if (l['details'] != null &&
                      l['details'].toString().isNotEmpty)
                    l['details'],
                  l['created_at']?.toString().substring(0, 16) ?? '',
                ].join(' · '),
                style: const TextStyle(fontSize: 11)),
          );
        },
      ),
    );
  }
}
