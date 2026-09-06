import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../screens/word_counter_screen.dart';
import '../screens/saved_paper_screen.dart';
import '../screens/plagarism_check_screen.dart';
import '../screens/citation_generation_screen.dart';
import '../screens/notebook_llm_screen.dart';
import '../screens/my_notes_screen.dart';
import '../screens/login_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppColors.logoGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.psychology_alt, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Orbirag",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _drawerItem(
                    context,
                    icon: Icons.text_fields,
                    title: "Word Counter",
                    onTap: () => _navigate(context, const WordCounterScreen()),
                  ),
                  _drawerItem(
                    context,
                    icon: Icons.menu_book_outlined,
                    title: "Literature Retrieval",
                    onTap: () {}, // Add your screen later
                  ),
                  _drawerItem(
                    context,
                    icon: Icons.edit_note,
                    title: "Methodology Writing",
                    onTap: () {}, // Add your screen later
                  ),
                  _drawerItem(
                    context,
                    icon: Icons.travel_explore,
                    title: "Guided Topic Scoping",
                    onTap: () {}, // Add your screen later
                  ),
                  _drawerItem(
                    context,
                    icon: Icons.note_alt_outlined,
                    title: "Notepad",
                    onTap: () => _navigate(context, const MyNotesScreen()),
                  ),
                  _drawerItem(
                    context,
                    icon: Icons.bookmark_border,
                    title: "Saved Papers",
                    onTap: () => _navigate(context, const SavedPapersScreen()),
                  ),
                  _drawerItem(
                    context,
                    icon: Icons.shield_outlined,
                    title: "Plagiarism Check",
                    onTap: () => _navigate(context, const PlagiarismCheckScreen()),
                  ),
                  _drawerItem(
                    context,
                    icon: Icons.format_quote,
                    title: "Citation Generation",
                    onTap: () => _navigate(context, const CitationGeneratorScreen()),
                  ),
                  _drawerItem(
                    context,
                    icon: Icons.auto_awesome,
                    title: "Notebook LLM",
                    onTap: () => _navigate(context, const NotebookLLMScreen()),
                  ),
                ],
              ),
            ),

            // Logout
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text(
                "Logout",
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
              ),
              onTap: () => _showLogoutDialog(context),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: () {
        Navigator.pop(context); // close drawer
        onTap();
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  void _navigate(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // close dialog
              Navigator.pop(context); // close drawer
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }
}