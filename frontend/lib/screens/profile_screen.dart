import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../utils/firebase_auth_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_brand_title.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_screen.dart';
import '../services/session_tracker_service.dart';
import '../services/papers_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedIndex = 3; // Profile is index 3
  final FirebaseAuthService _auth = FirebaseAuthService.instance;

  // Profile Data
  String? _profileImageUrl;
  Uint8List? _profileImageBytes;
  String _name = '';
  String _email = '';
  String _selectedRole = 'Undergraduate';
  bool _isEditMode = false;
  bool _isLoading = false;

  // Notification Data
  final List<Map<String, dynamic>> _notifications = [
    {
      'icon': Icons.article_outlined,
      'title': 'Related paper found',
      'message':
          'A new paper matches your interest in AI-assisted literature review.',
      'time': '2 hours ago'
    },
    {
      'icon': Icons.auto_awesome_outlined,
      'title': 'Paper recommendation',
      'message':
          'Our AI suggests a high-confidence paper based on your saved topics.',
      'time': '5 hours ago'
    },
    {
      'icon': Icons.bookmark_added_outlined,
      'title': 'Saved paper updated',
      'message':
          'A paper in your library has new citation activity and highlights.',
      'time': '1 day ago'
    },
    {
      'icon': Icons.library_books_outlined,
      'title': 'Reading list match',
      'message':
          'A relevant paper was added to your topic cluster for review.',
      'time': '2 days ago'
    },
  ];

  // Real Progress & Tracking Data
  bool _isLoadingStats = false;
  int _totalTimeSpentSeconds = 0;
  double _totalHours = 0.0;
  int _currentStreak = 0;
  int _papersRead = 0;
  List<String> _activeDates = [];
  Map<String, dynamic> _activeDatesDetail = {};
  Map<String, dynamic> _weeklyActivity = {};
  final ScrollController _heatmapScrollController = ScrollController();

  // Expanded Sections
  bool _isEditProfileExpanded = false;
  bool _isNotificationsExpanded = false;
  bool _isProgressExpanded = false;
  bool _isPrivacyExpanded = false;
  bool _isAboutExpanded = false;

  ImageProvider? get _avatarImageProvider {
    if (_profileImageBytes != null && _profileImageBytes!.isNotEmpty) {
      return MemoryImage(_profileImageBytes!);
    }
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      if (_profileImageUrl!.startsWith('http')) {
        return NetworkImage(_profileImageUrl!);
      }
      try {
        final clean = _profileImageUrl!.contains(',')
            ? _profileImageUrl!.split(',').last
            : _profileImageUrl!;
        final bytes = base64Decode(clean);
        if (bytes.isNotEmpty) {
          return MemoryImage(bytes);
        }
      } catch (_) {}
    }
    return null;
  }

  // ---- INIT ----

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    _name = user?.displayName ?? 'Alex Bennett';
    _email = user?.email ?? 'alex.bennett@university.edu';
    _loadProfileImage();
    _loadProfileStats();
  }

  @override
  void dispose() {
    _heatmapScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileStats() async {
    setState(() => _isLoadingStats = true);
    try {
      // Flush current elapsed time to backend first
      await SessionTrackerService.instance.flushHeartbeat();

      final stats = await SessionTrackerService.instance.fetchProfileStats();
      int papersCount = 0;
      try {
        papersCount = PapersService().getPapersByStatus('read').length;
      } catch (_) {}

      if (stats != null && mounted) {
        final sec = (stats['total_time_spent_seconds'] as num?)?.toInt() ?? 0;
        final serverPapers = (stats['papers_read'] as num?)?.toInt() ?? 0;
        setState(() {
          _totalTimeSpentSeconds = sec;
          _totalHours = (stats['total_hours'] as num?)?.toDouble() ?? (sec / 3600.0);
          _currentStreak = (stats['current_streak'] as num?)?.toInt() ?? 0;
          _papersRead = serverPapers > 0 ? serverPapers : papersCount;
          _activeDates = ((stats['active_dates'] as List<dynamic>?) ?? [])
              .map((e) => e.toString())
              .toList();
          _activeDatesDetail = (stats['active_dates_detail'] as Map<String, dynamic>?) ?? {};
          _weeklyActivity = (stats['weekly_activity'] as Map<String, dynamic>?) ?? {};
          _isLoadingStats = false;
        });
      } else if (mounted) {
        setState(() {
          _papersRead = papersCount;
          _isLoadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStats = false);
    }

    // Scroll heatmap towards current week after render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_heatmapScrollController.hasClients) {
        _heatmapScrollController.jumpTo(
          _heatmapScrollController.position.maxScrollExtent,
        );
      }
    });
  }

  Future<void> _loadProfileImage() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final base64Image = doc.data()?['photoBase64'] as String?;
      if (base64Image != null && mounted) {
        setState(() => _profileImageBytes = base64Decode(base64Image));
      }
    } catch (e) {
      debugPrint('Failed to load profile image: $e');
    }
  }

  // ---- EDIT PROFILE ----

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 300,
      maxHeight: 300,
    );
    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No signed-in user found.');

      // Cross-platform byte reading — works on Web, Mobile, and Desktop
      // (Fixes the Unsupported operation: _Namespace error)
      final bytes = await pickedFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      if (base64Image.length > 900000) {
        throw Exception('Image too large. Please choose a smaller photo.');
      }

      // 1. Sync to Firestore (for existing Firebase listeners)
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'photoBase64': base64Image}, SetOptions(merge: true));
      } catch (fe) {
        debugPrint('[Profile] Firestore avatar sync warning: $fe');
      }

      // 2. POST to PostgreSQL backend /api/users/update-avatar
      final baseUrl = kIsWeb
          ? 'http://localhost:8001'
          : (defaultTargetPlatform == TargetPlatform.android
              ? 'http://10.0.2.2:8001'
              : 'http://localhost:8001');

      try {
        final res = await http
            .post(
              Uri.parse('$baseUrl/api/users/update-avatar'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'email': user.email,
                'firebase_uid': user.uid,
                'avatar_base64': base64Image,
              }),
            )
            .timeout(const Duration(seconds: 15));
        debugPrint('[Profile] Backend avatar update status: ${res.statusCode}');
      } catch (be) {
        debugPrint('[Profile] Backend avatar update warning: $be');
      }

      if (!mounted) return;
      setState(() {
        _profileImageBytes = bytes;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      await _auth.updateProfile(displayName: _name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated!'),
          backgroundColor: AppColors.success,
        ),
      );
      setState(() => _isEditMode = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }


  @override
  Widget build(BuildContext context) {
    final List<String> roleLabels =
        AppConstants.roles.map((role) => role['label'] as String).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.textPrimary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const AppBrandTitle(),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.textPrimary,
            ),
            onPressed: () {
              Navigator.of(context).pushNamed(AppConstants.routePaperOrbit);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            _buildProfileHeader(roleLabels),
            const SizedBox(height: 24),

            // EDIT PROFILE SECTION
            _buildExpandableSection(
              title: 'Edit Profile',
              icon: Icons.person_outline,
              isExpanded: _isEditProfileExpanded,
              onTap: () => setState(
                  () => _isEditProfileExpanded = !_isEditProfileExpanded),
              content: _buildEditProfileContent(roleLabels),
            ),
            const SizedBox(height: 12),

            // NOTIFICATIONS
            _buildExpandableSection(
              title: 'Notifications',
              icon: Icons.notifications_none,
              isExpanded: _isNotificationsExpanded,
              onTap: () => setState(
                  () => _isNotificationsExpanded = !_isNotificationsExpanded),
              content: _buildNotificationsContent(),
            ),
            const SizedBox(height: 12),

            // MY PROGRESS
            _buildExpandableSection(
              title: 'My Progress',
              icon: Icons.show_chart,
              isExpanded: _isProgressExpanded,
              onTap: () =>
                  setState(() => _isProgressExpanded = !_isProgressExpanded),
              content: _buildProgressContent(),
            ),
            const SizedBox(height: 12),

            // PRIVACY & DATA
            _buildExpandableSection(
              title: 'Privacy & Data',
              icon: Icons.shield_outlined,
              isExpanded: _isPrivacyExpanded,
              onTap: () =>
                  setState(() => _isPrivacyExpanded = !_isPrivacyExpanded),
              content: _buildPrivacyContent(),
            ),
            const SizedBox(height: 12),

            // ABOUT ORBIRAG
            _buildExpandableSection(
              title: 'About Orbirag',
              icon: Icons.info_outline,
              isExpanded: _isAboutExpanded,
              onTap: () => setState(() => _isAboutExpanded = !_isAboutExpanded),
              content: _buildAboutContent(),
            ),

            // TEMPORARY — remove before submission
            const SizedBox(height: 24),
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminScreen()),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24, horizontal: 40),
                  child: Text(
                    'v1.0.0',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          final route = AppConstants.bottomNavItems[index]['route'] as String;
          Navigator.of(context).pushReplacementNamed(route);
        },
      ),
    );
  }


  Widget _buildProfileHeader(List<String> roleLabels) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Avatar with edit button
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.primary,
                backgroundImage: _avatarImageProvider,
                child: _avatarImageProvider == null
                    ? Text(
                        _name.isNotEmpty
                            ? _name.substring(0, 1).toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              if (_isEditMode)
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 16, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          _isEditMode
              ? TextField(
                  controller: TextEditingController(text: _name),
                  onChanged: (value) => _name = value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: UnderlineInputBorder(),
                    hintText: 'Enter your name',
                  ),
                )
              : Text(
                  _name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
          const SizedBox(height: 4),

          Text(
            _email,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),

          // Role Badge
          _isEditMode
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedRole,
                      isExpanded: true,
                      items: roleLabels.map((role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(role),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedRole = value!),
                    ),
                  ),
                )
              : Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    _selectedRole,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),

          if (_isEditMode) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Save Changes'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _isEditMode = false);
                      final user = _auth.currentUser;
                      _name = user?.displayName ?? 'Alex Bennett';
                      _profileImageUrl = user?.photoURL;
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---- EXPANDABLE SECTION BUILDER ----

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: onTap,
            leading: Icon(icon, color: AppColors.primary),
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: AppColors.textSecondary,
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: content,
            ),
        ],
      ),
    );
  }

  // ---- EDIT PROFILE CONTENT ----

  Widget _buildEditProfileContent(List<String> roleLabels) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Profile Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _isEditMode = true),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: _name),
            onChanged: (value) => _name = value,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
              color: AppColors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRole,
                isExpanded: true,
                items: roleLabels.map((role) {
                  return DropdownMenuItem<String>(
                    value: role,
                    child: Text(role),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedRole = value!),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text('Change Profile Photo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _isEditMode = false);
                    final user = _auth.currentUser;
                    _name = user?.displayName ?? 'Alex Bennett';
                    _profileImageUrl = user?.photoURL;
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- NOTIFICATIONS CONTENT ----

  Widget _buildNotificationsContent() {
    return Column(
      children: _notifications.map((notification) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(notification['icon'],
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification['title'],
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      notification['message'],
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Text(
                      notification['time'],
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.hintText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ---- PROGRESS CONTENT ----

  Widget _buildProgressContent() {
    final streakStr = _currentStreak == 1 ? '1 day' : '$_currentStreak days';
    final hoursStr = _totalHours > 0
        ? '${_totalHours.toStringAsFixed(1)}h'
        : _totalTimeSpentSeconds > 0
            ? '${(_totalTimeSpentSeconds / 60).round()}m'
            : '0h';

    return Column(
      children: [
        if (_isLoadingStats)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.primary,
              backgroundColor: Colors.transparent,
            ),
          ),
        Row(
          children: [
            _buildStatCard('Total Hours', hoursStr,
                Icons.access_time, AppColors.progressColor1),
            const SizedBox(width: 8),
            _buildStatCard('Papers Read', '$_papersRead',
                Icons.menu_book, AppColors.progressColor2),
            const SizedBox(width: 8),
            _buildStatCard('Streak', streakStr,
                Icons.local_fire_department, AppColors.warning),
          ],
        ),
        const SizedBox(height: 16),

        const Text(
          'Weekly Activity',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 10),
        _buildWeeklyActivityBarChart(),
        const SizedBox(height: 16),

        const Text(
          'Activity Overview',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        _buildContributionGraph(),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyActivityBarChart() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekValues = <int>[];

    for (int i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      final dateKey =
          "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
      final sec = (_weeklyActivity[dateKey] ??
              _activeDatesDetail[dateKey] as num?)
          ?.toInt() ??
          0;
      weekValues.add(sec);
    }

    final int maxSec =
        weekValues.fold(0, (prev, val) => val > prev ? val : prev);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: days.asMap().entries.map((entry) {
        final index = entry.key;
        final dayName = entry.value;
        final seconds = weekValues[index];
        final isToday = (index + 1) == now.weekday;

        final double barHeight = maxSec > 0 && seconds > 0
            ? ((seconds / maxSec) * 72.0 + 8.0).clamp(8.0, 80.0)
            : 6.0;

        final String tooltip = seconds >= 3600
            ? '${(seconds / 3600.0).toStringAsFixed(1)}h'
            : seconds >= 60
                ? '${(seconds / 60).round()}m'
                : '${seconds}s';

        return Tooltip(
          message: '$dayName: $tooltip',
          child: Column(
            children: [
              Container(
                width: 24,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isToday
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      height: barHeight,
                      decoration: BoxDecoration(
                        gradient: seconds > 0
                            ? const LinearGradient(
                                colors: [
                                  AppColors.progressColor1,
                                  AppColors.progressColor2,
                                ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              )
                            : null,
                        color: seconds == 0
                            ? AppColors.border.withValues(alpha: 0.6)
                            : null,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dayName,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildContributionGraph() {
    final now = DateTime.now();
    final currentYear = now.year;
    final jan1 = DateTime(currentYear, 1, 1);
    final daysBefore = jan1.weekday % 7; // Sunday start
    final gridStartDate = jan1.subtract(Duration(days: daysBefore));

    const totalWeeks = 53;
    const boxSize = 11.0;
    const boxMargin = 1.5;

    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final weekMonthLabels = <int, String>{};
    for (int w = 0; w < totalWeeks; w++) {
      final cellDate = gridStartDate.add(Duration(days: w * 7));
      if (cellDate.year == currentYear && cellDate.day <= 7) {
        weekMonthLabels[w] = monthNames[cellDate.month - 1];
      }
    }

    final levelColors = [
      AppColors.cardBg,
      AppColors.progressColor1.withValues(alpha: 0.25),
      AppColors.progressColor1.withValues(alpha: 0.50),
      AppColors.progressColor1.withValues(alpha: 0.75),
      AppColors.progressColor1,
    ];

    Color getCellColor(DateTime date) {
      if (date.year != currentYear) return Colors.transparent;
      if (date.isAfter(now)) {
        return AppColors.cardBg.withValues(alpha: 0.4);
      }
      final key =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      if (!_activeDates.contains(key) && !_activeDatesDetail.containsKey(key)) {
        return AppColors.cardBg;
      }
      final sec = (_activeDatesDetail[key] as num?)?.toInt() ?? 60;
      if (sec <= 0) return AppColors.cardBg;
      if (sec < 900) return levelColors[1];
      if (sec < 2700) return levelColors[2];
      if (sec < 5400) return levelColors[3];
      return levelColors[4];
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            controller: _heatmapScrollController,
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month labels row
                Row(
                  children: List.generate(totalWeeks, (w) {
                    final label = weekMonthLabels[w] ?? '';
                    return SizedBox(
                      width: boxSize + boxMargin * 2,
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                        softWrap: false,
                        overflow: TextOverflow.visible,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 4),

                // 7 rows (Sunday to Saturday)
                Column(
                  children: List.generate(7, (row) {
                    return Row(
                      children: List.generate(totalWeeks, (col) {
                        final cellDate =
                            gridStartDate.add(Duration(days: col * 7 + row));
                        final isRealYear = cellDate.year == currentYear;
                        final isFuture = cellDate.isAfter(now);
                        final dateKey =
                            "${cellDate.year}-${cellDate.month.toString().padLeft(2, '0')}-${cellDate.day.toString().padLeft(2, '0')}";
                        final cellColor = getCellColor(cellDate);
                        final sec =
                            (_activeDatesDetail[dateKey] as num?)?.toInt() ?? 0;

                        if (!isRealYear) {
                          return Container(
                            width: boxSize,
                            height: boxSize,
                            margin: const EdgeInsets.all(boxMargin),
                            color: Colors.transparent,
                          );
                        }

                        final String tooltip = isFuture
                            ? dateKey
                            : sec > 0
                                ? '$dateKey: ${_formatDuration(sec)} active'
                                : '$dateKey: No activity';

                        return Tooltip(
                          message: tooltip,
                          child: Container(
                            width: boxSize,
                            height: boxSize,
                            margin: const EdgeInsets.all(boxMargin),
                            decoration: BoxDecoration(
                              color: cellColor,
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(
                                color: isFuture
                                    ? Colors.transparent
                                    : AppColors.border.withValues(alpha: 0.5),
                                width: 0.5,
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Legend and summary footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_activeDates.length} active ${_activeDates.length == 1 ? "day" : "days"} in $currentYear',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              Row(
                children: [
                  const Text('Less ',
                      style: TextStyle(
                          fontSize: 8, color: AppColors.textSecondary)),
                  ...levelColors.map((color) => Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.6),
                            width: 0.5,
                          ),
                        ),
                      )),
                  const Text(' More',
                      style: TextStyle(
                          fontSize: 8, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds >= 3600) {
      final h = (seconds / 3600.0).toStringAsFixed(1);
      return '${h}h';
    }
    if (seconds >= 60) {
      return '${(seconds / 60).round()}m';
    }
    return '${seconds}s';
  }

  // ---- PRIVACY CONTENT ----

  Widget _buildPrivacyContent() {
    return Column(
      children: [
        _buildPrivacyItem(
          icon: Icons.security,
          title: 'Data Security',
          description: 'Your data is encrypted and stored securely.',
        ),
        const SizedBox(height: 8),
        _buildPrivacyItem(
          icon: Icons.shield,
          title: 'Privacy Policy',
          description: 'Read how we handle your data.',
        ),
        const SizedBox(height: 8),
        _buildPrivacyItem(
          icon: Icons.download,
          title: 'Download Data',
          description: 'Export your data in machine-readable format.',
        ),
        const SizedBox(height: 8),
        _buildPrivacyItem(
          icon: Icons.delete,
          title: 'Delete Account',
          description: 'Permanently delete your account.',
          isDanger: true,
        ),
      ],
    );
  }

  Widget _buildPrivacyItem({
    required IconData icon,
    required String title,
    required String description,
    bool isDanger = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: isDanger ? Border.all(color: AppColors.error) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDanger
                  ? AppColors.error.withValues(alpha: 0.1)
                  : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon,
                color: isDanger ? AppColors.error : AppColors.primary,
                size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDanger ? AppColors.error : AppColors.textPrimary,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right,
              color: isDanger ? AppColors.error : AppColors.textSecondary,
              size: 18),
        ],
      ),
    );
  }

  // ---- ABOUT CONTENT ----

  Widget _buildAboutContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your first step into research.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Orbirag is an AI research mentor for students who don\'t know '
          'where to start — no experience needed, no question too basic.',
          style: TextStyle(
              fontSize: 13, color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 12),
        _buildAboutFeature('🎯', 'Scope Your Topic',
            'Turn a vague idea into a clear research question.'),
        _buildAboutFeature('📚', 'Find & Understand Papers',
            'Search literature, spot gaps, chat with any paper.'),
        _buildAboutFeature('✍️', 'Write Your Methodology',
            'Get step-by-step guidance and examples.'),
        _buildAboutFeature('🛡️', 'Check Your Work',
            'Catch similarity issues, generate citations.'),
        _buildAboutFeature('🔖', 'Save Your Progress',
            'Build a personal library of saved papers.'),
        _buildAboutFeature(
            '📝', 'Word Counter', 'Track your writing length as you go.'),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminScreen()),
              );
            },
            child: const Text(
              'Orbirag · v1.0',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutFeature(String emoji, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  description,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}