import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../utils/firebase_auth_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/app_drawer.dart';

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
  String _name = '';
  String _email = '';
  String _selectedRole = 'Undergraduate';
  bool _isEditMode = false;
  bool _isLoading = false;
  
  // Notification Data
  final List<Map<String, dynamic>> _notifications = [
    {'icon': Icons.person_add, 'title': 'New follower', 'message': 'Sarah Johnson started following you', 'time': '2 hours ago'},
    {'icon': Icons.bookmark, 'title': 'Paper saved', 'message': 'Your paper was saved by 5 researchers', 'time': '4 hours ago'},
    {'icon': Icons.comment, 'title': 'New comment', 'message': 'Dr. Smith commented on your research', 'time': '1 day ago'},
    {'icon': Icons.emoji_events, 'title': 'Achievement unlocked', 'message': 'You reached 50 papers saved!', 'time': '2 days ago'},
  ];

  // Progress Data
  final Map<String, dynamic> _progressData = {
    'totalHours': '127',
    'papersRead': '34',
    'citations': '12',
    'streak': '7 days',
    'weeklyData': [12, 8, 15, 10, 20, 5, 18],
  };

  // Expanded Sections
  bool _isEditProfileExpanded = false;
  bool _isNotificationsExpanded = false;
  bool _isProgressExpanded = false;
  bool _isPrivacyExpanded = false;
  bool _isAboutExpanded = false;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    _profileImageUrl = user?.photoURL;
    _name = user?.displayName ?? 'Alex Bennett';
    _email = user?.email ?? 'alex.bennett@university.edu';
  }

  // ==================== EDIT PROFILE ====================

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImageUrl = pickedFile.path;
      });
      // TODO: Upload to Firebase Storage
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      await _auth.updateProfile(displayName: _name);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated!'), backgroundColor: AppColors.success),
      );
      setState(() => _isEditMode = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
    setState(() => _isLoading = false);
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    // FIXED: Convert roles list to List<String> for DropdownButton
    final List<String> roleLabels = AppConstants.roles.map((role) => role['label'] as String).toList();

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
        title: const Text(
          AppConstants.appName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_outlined, color: AppColors.textPrimary),
            onPressed: () {
              Navigator.of(context).pushNamed(AppConstants.routeNotebookLLM);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // ============================================
            // PROFILE HEADER
            // ============================================
            _buildProfileHeader(roleLabels),
            const SizedBox(height: 24),

            // ============================================
            // EDIT PROFILE SECTION (Expandable)
            // ============================================
            _buildExpandableSection(
              title: 'Edit Profile',
              icon: Icons.person_outline,
              isExpanded: _isEditProfileExpanded,
              onTap: () => setState(() => _isEditProfileExpanded = !_isEditProfileExpanded),
              content: _buildEditProfileContent(roleLabels),
            ),
            const SizedBox(height: 12),

            // ============================================
            // NOTIFICATIONS SECTION (Expandable)
            // ============================================
            _buildExpandableSection(
              title: 'Notifications',
              icon: Icons.notifications_none,
              isExpanded: _isNotificationsExpanded,
              onTap: () => setState(() => _isNotificationsExpanded = !_isNotificationsExpanded),
              content: _buildNotificationsContent(),
            ),
            const SizedBox(height: 12),

            // ============================================
            // MY PROGRESS SECTION (Expandable)
            // ============================================
            _buildExpandableSection(
              title: 'My Progress',
              icon: Icons.show_chart,
              isExpanded: _isProgressExpanded,
              onTap: () => setState(() => _isProgressExpanded = !_isProgressExpanded),
              content: _buildProgressContent(),
            ),
            const SizedBox(height: 12),

            // ============================================
            // PRIVACY & DATA SECTION (Expandable)
            // ============================================
            _buildExpandableSection(
              title: 'Privacy & Data',
              icon: Icons.shield_outlined,
              isExpanded: _isPrivacyExpanded,
              onTap: () => setState(() => _isPrivacyExpanded = !_isPrivacyExpanded),
              content: _buildPrivacyContent(),
            ),
            const SizedBox(height: 12),

            // ============================================
            // ABOUT ORBIRAG SECTION (Expandable)
            // ============================================
            _buildExpandableSection(
              title: 'About Orbirag',
              icon: Icons.info_outline,
              isExpanded: _isAboutExpanded,
              onTap: () => setState(() => _isAboutExpanded = !_isAboutExpanded),
              content: _buildAboutContent(),
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

  // ============================================
  // PROFILE HEADER
  // ============================================

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
                backgroundImage: _profileImageUrl != null && _profileImageUrl!.startsWith('http')
                    ? NetworkImage(_profileImageUrl!)
                    : _profileImageUrl != null
                        ? FileImage(File(_profileImageUrl!)) as ImageProvider
                        : null,
                child: _profileImageUrl == null
                    ? Text(
                        _name.substring(0, 1).toUpperCase(),
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
                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Name
          _isEditMode
              ? TextField(
                  controller: TextEditingController(text: _name),
                  onChanged: (value) => _name = value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

          // Email
          Text(
            _email,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),

          // Role Badge - FIXED: Pass roleLabels
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
                      onChanged: (value) => setState(() => _selectedRole = value!),
                    ),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    _selectedRole,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
          ] else ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() => _isEditMode = true),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit Profile'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================
  // EXPANDABLE SECTION BUILDER
  // ============================================

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

  // ============================================
  // EDIT PROFILE CONTENT - FIXED
  // ============================================

  Widget _buildEditProfileContent(List<String> roleLabels) {
    return Column(
      children: [
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
        ElevatedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.photo_camera),
          label: const Text('Change Profile Photo'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  // ============================================
  // NOTIFICATIONS CONTENT
  // ============================================

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
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(notification['icon'], color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification['title'],
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      notification['message'],
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Text(
                      notification['time'],
                      style: const TextStyle(fontSize: 10, color: AppColors.hintText),
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

  // ============================================
  // PROGRESS CONTENT
  // ============================================

  Widget _buildProgressContent() {
    return Column(
      children: [
        // Stats Row
        Row(
          children: [
            _buildStatCard('Total Hours', _progressData['totalHours'], Icons.access_time, AppColors.progressColor1),
            const SizedBox(width: 8),
            _buildStatCard('Papers Read', _progressData['papersRead'], Icons.menu_book, AppColors.progressColor2),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildStatCard('Citations', _progressData['citations'], Icons.format_quote, AppColors.progressColor3),
            const SizedBox(width: 8),
            _buildStatCard('Streak', _progressData['streak'], Icons.local_fire_department, AppColors.warning),
          ],
        ),
        const SizedBox(height: 16),

        // Weekly Activity
        const Text(
          'Weekly Activity',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].asMap().entries.map((entry) {
            final index = entry.key;
            final day = entry.value;
            final value = (_progressData['weeklyData'] as List<int>)[index];
            return Column(
              children: [
                Container(
                  width: 24,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        height: (value / 20) * 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.progressColor1, AppColors.progressColor2],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(day, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 8),

        // GitHub-style contribution graph
        const Text(
          'Activity Overview',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        _buildContributionGraph(),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContributionGraph() {
    final colors = [
      AppColors.cardBg,
      AppColors.progressColor1.withOpacity(0.2),
      AppColors.progressColor1.withOpacity(0.4),
      AppColors.progressColor1.withOpacity(0.6),
      AppColors.progressColor1,
    ];

    return Column(
      children: [
        ...List.generate(5, (row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: List.generate(15, (col) {
                final intensity = (row * 3 + col) % 5;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(1.5),
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[intensity],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('Less', style: TextStyle(fontSize: 8, color: AppColors.textSecondary)),
            ...colors.map((color) => Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                )),
            const Text('More', style: TextStyle(fontSize: 8, color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }

  // ============================================
  // PRIVACY CONTENT
  // ============================================

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
              color: isDanger ? AppColors.error.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: isDanger ? AppColors.error : AppColors.primary, size: 18),
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
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: isDanger ? AppColors.error : AppColors.textSecondary, size: 18),
        ],
      ),
    );
  }

  // ============================================
  // ABOUT CONTENT
  // ============================================

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
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 12),

        _buildAboutFeature('🎯', 'Scope Your Topic', 'Turn a vague idea into a clear research question.'),
        _buildAboutFeature('📚', 'Find & Understand Papers', 'Search literature, spot gaps, chat with any paper.'),
        _buildAboutFeature('✍️', 'Write Your Methodology', 'Get step-by-step guidance and examples.'),
        _buildAboutFeature('🛡️', 'Check Your Work', 'Catch similarity issues, generate citations.'),
        _buildAboutFeature('🔖', 'Save Your Progress', 'Build a personal library of saved papers.'),
        _buildAboutFeature('📝', 'Word Counter', 'Track your writing length as you go.'),

        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Orbirag · v1.0',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
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
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}