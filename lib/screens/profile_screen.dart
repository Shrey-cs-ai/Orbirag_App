import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../widgets/app_scaffold.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Orbirag",
      actions: [IconButton(icon: const Icon(Icons.bolt_outlined), onPressed: () {})],
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Profile Avatar
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                const CircleAvatar(
                  radius: 48,
                  backgroundImage: NetworkImage(
                    "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200",
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text(
              "Alex Bennett",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              "alex.bennett@university.edu",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),

            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Undergraduate", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  SizedBox(width: 6),
                  Icon(Icons.edit, size: 14, color: AppColors.textSecondary),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Menu items
            _buildMenuItem(Icons.person_outline, "Edit Profile", () {}),
            _buildMenuItem(Icons.notifications_none, "Notifications", () {}),
            _buildMenuItem(Icons.show_chart, "My Progress", () {}),
            _buildMenuItem(Icons.bookmark_border, "Saved Papers", () {
              // Navigate to SavedPapersScreen
            }),
            _buildMenuItem(Icons.shield_outlined, "Privacy & Data", () {}),
            _buildMenuItem(Icons.info_outline, "About Orbirag", () {}),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }
}