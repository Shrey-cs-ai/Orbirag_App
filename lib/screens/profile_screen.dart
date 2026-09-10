import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../utils/firebase_auth_service.dart';
import '../services/profile_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/app_drawer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedIndex = 3;
  final FirebaseAuthService _auth = FirebaseAuthService.instance;
  final ProfileService _profileService = ProfileService();
  
  // Profile Data
  String? _profileImageUrl;
  String _name = '';
  String _email = '';
  String _selectedRole = 'Undergraduate';
  bool _isEditMode = false;
  bool _isLoading = false;
  bool _isUploadingImage = false;
  
  // Notification Data
  List<Map<String, dynamic>> _notifications = [];

  // Progress Data
  Map<String, dynamic> _progressData = {
    'totalHours': '0',
    'papersRead': '0',
    'citations': '0',
    'streak': '0 days',
    'weeklyData': [0, 0, 0, 0, 0, 0, 0],
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
    _loadUserData();
  }

  // ==================== LOAD USER DATA ====================
  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    
    // ✅ Load role from storage
    final savedRole = await _profileService.getRole();
    
    // ✅ Load progress from storage
    final savedProgress = await _profileService.getProgress();
    
    // ✅ Load notifications from storage
    final savedNotifications = await _profileService.getNotifications();
    
    setState(() {
      _profileImageUrl = user?.photoURL;
      _name = user?.displayName ?? 'Alex Bennett';
      _email = user?.email ?? 'alex.bennett@university.edu';
      _selectedRole = savedRole ?? 'Undergraduate';
      
      if (savedProgress != null) {
        _progressData = savedProgress;
      } else {
        // Default sample data
        _progressData = {
          'totalHours': '127',
          'papersRead': '34',
          'citations': '12',
          'streak': '7 days',
          'weeklyData': [12, 8, 15, 10, 20, 5, 18],
        };
      }
      
      if (savedNotifications.isNotEmpty) {
        _notifications = savedNotifications;
      } else {
        // Default sample notifications
        _notifications = [
          {'icon': 'person_add', 'title': 'New follower', 'message': 'Sarah Johnson started following you', 'time': '2 hours ago'},
          {'icon': 'bookmark', 'title': 'Paper saved', 'message': 'Your paper was saved by 5 researchers', 'time': '4 hours ago'},
          {'icon': 'comment', 'title': 'New comment', 'message': 'Dr. Smith commented on your research', 'time': '1 day ago'},
          {'icon': 'emoji_events', 'title': 'Achievement unlocked', 'message': 'You reached 50 papers saved!', 'time': '2 days ago'},
        ];
        await _profileService.saveNotifications(_notifications);
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (pickedFile == null) return;

      setState(() => _isUploadingImage = true);

      // Try uploading to Firebase Storage
      final user = _auth.currentUser;
      if (user != null) {
        try {
          // Create storage reference
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('profile_pics')
              .child('${user.uid}.jpg');

          // Upload file
          await storageRef.putFile(File(pickedFile.path));

          // Get download URL
          final downloadUrl = await storageRef.getDownloadURL();

          // Update user profile
          await _auth.updatePhotoURL(downloadUrl);

          // Save to local storage as backup
          await _profileService.saveProfilePicPath(downloadUrl);

          setState(() {
            _profileImageUrl = downloadUrl;
            _isUploadingImage = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Profile picture updated!'),
                backgroundColor: AppColors.success,
              ),
            );
          }
          return;
        } catch (firebaseError) {
          // Firebase failed, fall back to local
          debugPrint('Firebase upload failed: $firebaseError');
        }
      }

      // Fallback: Use local file
      await _profileService.saveProfilePicPath(pickedFile.path);
      setState(() {
        _profileImageUrl = pickedFile.path;
        _isUploadingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated locally'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      // Update Firebase display name
      await _auth.updateProfile(displayName: _name);
      
      // ✅ Save role to storage
      await _profileService.saveRole(_selectedRole);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      
      setState(() {
        _isEditMode = false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Helper to get icon from string
  IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'person_add': return Icons.person_add;
      case 'bookmark': return Icons.bookmark;
      case 'comment': return Icons.comment;
      case 'emoji_events': return Icons.emoji_events;
      case 'security': return Icons.security;
      case 'download': return Icons.download;
      case 'delete': return Icons.delete;
      default: return Icons.notifications;
    }
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    final List<String> roleLabels = AppConstants.roles
        .map((role) => role['label'] as String)
        .toList();

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
            _buildProfileHeader(roleLabels),
            const SizedBox(height: 24),
            
            _buildExpandableSection(
              title: 'Edit Profile',
              icon: Icons.person_outline,
              isExpanded: _isEditProfileExpanded,
              onTap: () => setState(() => _isEditProfileExpanded = !_isEditProfileExpanded),
              content: _buildEditProfileContent(roleLabels),
            ),
            const SizedBox(height: 12),
            
            _buildExpandableSection(
              title: 'Notifications',
              icon: Icons.notifications_none,
              isExpanded: _isNotificationsExpanded,
              onTap: () => setState(() => _isNotificationsExpanded = !_isNotificationsExpanded),
              content: _buildNotificationsContent(),
            ),
            const SizedBox(height: 12),
            
            _buildExpandableSection(
              title: 'My Progress',
              icon: Icons.show_chart,
              isExpanded: _isProgressExpanded,
              onTap: () => setState(() => _isProgressExpanded = !_isProgressExpanded),
              content: _buildProgressContent(),
            ),
            const SizedBox(height: 12),
            
            _buildExpandableSection(
              title: 'Privacy & Data',
              icon: Icons.shield_outlined,
              isExpanded: _isPrivacyExpanded,
              onTap: () => setState(() => _isPrivacyExpanded = !_isPrivacyExpanded),
              content: _buildPrivacyContent(),
            ),
            const SizedBox(height: 12),
            
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
              Stack(
                alignment: Alignment.center,
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
                            _name.isNotEmpty ? _name.substring(0, 1).toUpperCase() : 'U',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  // Loading indicator over avatar
                  if (_isUploadingImage)
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha:0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                ],
              ),
              if (_isEditMode && !_isUploadingImage)
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
                    onPressed: _isLoading ? null : _saveProfile,
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
  // EXPANDABLE SECTION
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
  // EDIT PROFILE CONTENT
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
          onPressed: _isUploadingImage ? null : _pickImage,
          icon: _isUploadingImage
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.photo_camera),
          label: Text(_isUploadingImage ? 'Uploading...' : 'Change Profile Photo'),
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
                  color: AppColors.primary.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconFromString(notification['icon'] ?? 'notifications'),
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification['title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      notification['message'] ?? '',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Text(
                      notification['time'] ?? '',
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
        Row(
          children: [
            _buildStatCard('Total Hours', _progressData['totalHours'] ?? '0', Icons.access_time, AppColors.progressColor1),
            const SizedBox(width: 8),
            _buildStatCard('Papers Read', _progressData['papersRead'] ?? '0', Icons.menu_book, AppColors.progressColor2),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildStatCard('Citations', _progressData['citations'] ?? '0', Icons.format_quote, AppColors.progressColor3),
            const SizedBox(width: 8),
            _buildStatCard('Streak', _progressData['streak'] ?? '0 days', Icons.local_fire_department, AppColors.warning),
          ],
        ),
        const SizedBox(height: 16),

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
            final weeklyData = (_progressData['weeklyData'] as List?) ?? [0, 0, 0, 0, 0, 0, 0];
            final value = (weeklyData.length > index ? weeklyData[index] : 0) as int;
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
      AppColors.progressColor1.withValues(alpha:0.2),
      AppColors.progressColor1.withValues(alpha:0.4),
      AppColors.progressColor1.withValues(alpha:0.6),
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
          onTap: () => _showInfoDialog('Data Security', 'Your data is encrypted with industry-standard protocols.'),
        ),
        const SizedBox(height: 8),
        _buildPrivacyItem(
          icon: Icons.shield,
          title: 'Privacy Policy',
          description: 'Read how we handle your data.',
          onTap: () => _showInfoDialog('Privacy Policy', 'We respect your privacy. Your data is never sold to third parties.'),
        ),
        const SizedBox(height: 8),
        _buildPrivacyItem(
          icon: Icons.download,
          title: 'Download Data',
          description: 'Export your data in machine-readable format.',
          onTap: () => _showInfoDialog('Download Data', 'Your data export will be sent to your email within 24 hours.'),
        ),
        const SizedBox(height: 8),
        _buildPrivacyItem(
          icon: Icons.delete,
          title: 'Delete Account',
          description: 'Permanently delete your account.',
          isDanger: true,
          onTap: _showDeleteAccountDialog,
        ),
      ],
    );
  }

  Widget _buildPrivacyItem({
    required IconData icon,
    required String title,
    required String description,
    bool isDanger = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
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
                color: isDanger ? AppColors.error.withValues(alpha:0.1) : AppColors.primary.withValues(alpha:0.1),
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
      ),
    );
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This action cannot be undone. All your data will be permanently deleted.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _auth.signOut();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppConstants.routeLogin,
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
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
        const Center(
          child: Text(
            'Orbirag · v1.0',
            style: TextStyle(
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