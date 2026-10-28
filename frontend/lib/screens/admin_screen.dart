// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/admin/activity_tile.dart';
import '../widgets/admin/admin_empty_state.dart';
import '../widgets/admin/admin_loading_state.dart';
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
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          'Orbirag Admin',
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textPrimary),
            tooltip: 'Log out',
            onPressed: widget.onLogout,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          dividerColor: AppColors.border,
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
    final activeStudents = (_summary?['active_students'] as num?)?.toInt() ?? 0;
    final planRaw = (_inst?['plan'] ?? 'Standard').toString();
    final planDisplayName = planRaw
        .replaceAll('_', ' ')
        .split(' ')
        .map(
            (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');

    final renewalDateStr = _inst?['renewal_date']?.toString();
    DateTime? renewalDate;
    if (renewalDateStr != null && renewalDateStr.isNotEmpty) {
      renewalDate = DateTime.tryParse(renewalDateStr);
    }
    final int daysLeft =
        renewalDate != null ? renewalDate.difference(DateTime.now()).inDays : 0;

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
              badgeColor: daysLeft < 60 ? AppColors.warning : AppColors.success,
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
    final gapAnalyses =
        ((_summary?['gap_analysis'] ?? _summary?['gap_analyses']) as num?)
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
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
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
                  .map((w) => w.isNotEmpty
                      ? '${w[0].toUpperCase()}${w.substring(1)}'
                      : '')
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

  Color _statusColor(String? status) {
    if (status == 'active') return AppColors.success;
    if (status == 'suspended') return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Column(
        children: [
          // ── Search bar card ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by name or email…',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 6),
                      ),
                      onSubmitted: (_) => _load(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _statusFilter,
                        isDense: true,
                        hint: Text(
                          'All',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        icon: const Icon(Icons.expand_more,
                            size: 16, color: AppColors.primary),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All')),
                          DropdownMenuItem(
                              value: 'active', child: Text('Active')),
                          DropdownMenuItem(
                              value: 'suspended', child: Text('Suspended')),
                          DropdownMenuItem(
                              value: 'banned', child: Text('Banned')),
                        ],
                        onChanged: (v) {
                          setState(() => _statusFilter = v);
                          _load();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Loading bar ──────────────────────────────────────────────
          if (_loading)
            const LinearProgressIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.border,
              minHeight: 2,
            ),

          // ── List ─────────────────────────────────────────────────────
          Expanded(
            child: _loading && _items.isEmpty
                ? const AdminLoadingList()
                : _items.isEmpty
                    ? AdminEmptyState(
                        icon: Icons.people_outline,
                        title: 'No students found',
                        subtitle: _statusFilter != null
                            ? 'Try clearing the filter or search'
                            : 'Add students via the Dashboard quick actions',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final s = _items[i];
                            final sc = _statusColor(s['status']?.toString());
                            final initial = (s['name'] ?? '?')
                                .toString()
                                .characters
                                .first
                                .toUpperCase();
                            return GestureDetector(
                              onTap: () => _openStudent(s['id'] as int),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border:
                                      Border.all(color: AppColors.border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.textPrimary
                                          .withValues(alpha: 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor:
                                          AppColors.primary.withValues(alpha: 0.12),
                                      child: Text(
                                        initial,
                                        style: GoogleFonts.manrope(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s['name'] ?? '',
                                            style: GoogleFonts.manrope(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            s['email'] ?? '',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: sc.withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${s['status']}'.toUpperCase(),
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: sc,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
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
        ? AppColors.success
        : s['status'] == 'suspended'
            ? AppColors.warning
            : AppColors.error;

    return Container(
      color: AppColors.background,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Center(
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    (s['name'] ?? '?')
                        .toString()
                        .characters
                        .first
                        .toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  s['name'] ?? '',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Center(
                child: Text(
                  s['email'] ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${s['status']}'.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
              Divider(color: AppColors.border, height: 32),
              _row('Joined',
                  s['created_at']?.toString().substring(0, 10) ?? '—'),
              _row('Last active',
                  s['last_active_at']?.toString().substring(0, 10) ?? '—'),
              if (s['ban_reason'] != null) _row('Reason', s['ban_reason']),
              Divider(color: AppColors.border, height: 32),
              Text(
                'Usage summary (aggregated only)',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _chip('Gap analyses', counts['gap_analysis'] ?? 0),
                _chip('Citations', counts['citation_check'] ?? 0),
                _chip('Plagiarism', counts['plagiarism_check'] ?? 0),
                _chip('Papers', counts['paper_analysis'] ?? 0),
              ]),
              const SizedBox(height: 6),
              Text(
                'Research content is not visible to admins.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
              Divider(color: AppColors.border, height: 32),
              Text(
                'Actions',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.cardBg,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _changeStatus(context, s['id'], 'active'),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Activate'),
                  ),
                if (s['status'] == 'active') ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: BorderSide(color: AppColors.warning),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _changeStatus(
                        context, s['id'], 'suspended',
                        reason: 'Temporary suspension'),
                    icon: const Icon(Icons.pause, size: 16),
                    label: const Text('Suspend (7d)'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _changeStatus(context, s['id'], 'banned',
                        reason: 'Policy violation'),
                    icon: const Icon(Icons.block, size: 16),
                    label: const Text('Ban'),
                  ),
                ],
              ]),
              const SizedBox(height: 8),
            ]),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(
            width: 100,
            child: Text(
              k,
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
        ]),
      );

  Widget _chip(String label, dynamic count) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          '$label: $count',
          style: GoogleFonts.inter(
              fontSize: 11, color: AppColors.textPrimary),
        ),
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
      color: AppColors.primary,
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
    if (_err != null) {
      return ColoredBox(
        color: AppColors.background,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text(
                  'Failed to load analytics',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _err!,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.cardBg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_features == null) {
      return ColoredBox(
        color: AppColors.background,
        child: const AdminLoadingList(),
      );
    }

    return ColoredBox(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Privacy-safe info banner
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.privacy_tip_outlined,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Aggregated feature usage across the institution (Privacy-Safe)',
                      style: GoogleFonts.inter(
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
      ),
    );
  }

  Widget _buildCategoryCard(_FeatureCategory category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      Icon(category.icon, size: 18, color: category.color),
                ),
                const SizedBox(width: 10),
                Text(
                  category.title,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
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
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              _formatPercentage(pct),
              style: GoogleFonts.manrope(
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
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatStudents(users),
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.textSecondary,
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
    final color = isSuccess ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        isSuccess ? 'Success' : 'Blocked',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _logins == null) {
      return ColoredBox(
        color: AppColors.background,
        child: const AdminLoadingList(),
      );
    }
    if (_err != null && _logins == null) {
      return ColoredBox(
        color: AppColors.background,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_outlined, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text(
                  'Failed to load logins',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _err!,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.cardBg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final items = _logins ?? [];

    if (items.isEmpty) {
      return ColoredBox(
        color: AppColors.background,
        child: const AdminEmptyState(
          icon: Icons.login_outlined,
          title: 'No login activity yet',
          subtitle: 'Recent logins will appear here',
        ),
      );
    }

    return ColoredBox(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final log = items[index] as Map<String, dynamic>;
            final name = (log['student_name'] ?? 'Unknown').toString();
            final email = (log['email'] ?? '').toString();
            final role = (log['role'] ?? 'student').toString();
            final photoUrl = log['photo_url']?.toString();
            final time = log['login_time']?.toString();
            final status = (log['status'] ?? 'success').toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    _buildAvatar(photoUrl, name),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _buildRoleBadge(role),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _timeAgo(time),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildStatusBadge(status),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
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
    return ColoredBox(
      color: AppColors.background,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        // Header card
        Container(
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.shield_outlined,
                      color: AppColors.success, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Student Privacy by Default',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(
                  'Orbirag is built so that institutional control is separated from '
                  'student research. Admins manage access and view aggregated usage — '
                  'not the student\'s intellectual work.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _section(context, 'Admins CAN access', AppColors.success, [
          'Account information (name, email, role)',
          'Account status (active / suspended / banned)',
          'Aggregated usage counts per student',
          'Institution-wide analytics',
          'Audit logs of admin actions',
        ]),
        const SizedBox(height: 16),
        _section(context, 'Admins CANNOT access', AppColors.error, [
          'Private research projects or topics',
          'Chat conversations with the AI',
          'AI prompts or responses',
          'Draft papers or uploaded PDFs',
          'Personal research notes',
          'Full plagiarism reports containing student text',
        ]),
        const SizedBox(height: 16),
        // AI-likelihood card
        Container(
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.info_outline,
                      color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'AI-likelihood indicators',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  'If AI-likelihood indicators are ever surfaced to admins, they are '
                  'aggregated across the institution and clearly labelled as '
                  'AI-likelihood — not proof of misconduct.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _section(
      BuildContext ctx, String title, Color color, List<String> items) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    title.contains('CANNOT')
                        ? Icons.cancel_outlined
                        : Icons.check_circle_outline,
                    color: color,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      i,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ]),
      ),
    );
  }
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
    if (_err != null) {
      return ColoredBox(
        color: AppColors.background,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text(
                  'Failed to load audit logs',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _err!,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.cardBg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_logs == null) {
      return ColoredBox(
        color: AppColors.background,
        child: const AdminLoadingList(),
      );
    }
    if (_logs!.isEmpty) {
      return ColoredBox(
        color: AppColors.background,
        child: const AdminEmptyState(
          icon: Icons.history_outlined,
          title: 'No audit entries yet',
          subtitle: 'Admin actions will appear here',
        ),
      );
    }

    return ColoredBox(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _logs!.length,
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
                                ? Icons.check_circle_outline
                                : Icons.history_outlined;
            final iconColor = action.contains('ban')
                ? AppColors.error
                : action.contains('unban') || action.contains('login')
                    ? AppColors.success
                    : AppColors.primary;

            final subtitle = [
              if (l['target_student_id'] != null)
                'Student #${l['target_student_id']}',
              if (l['details'] != null &&
                  l['details'].toString().isNotEmpty)
                l['details'],
              l['created_at']?.toString().substring(0, 16) ?? '',
            ].join(' · ');

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Icon bubble
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 20, color: iconColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            action.replaceAll('_', ' ').toUpperCase(),
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
