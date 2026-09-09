import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/firebase_auth_service.dart';
import '../screens/home_screen.dart';
import '../screens/word_counter_screen.dart';
import '../screens/literature_retrieval_screen.dart';
import '../screens/methodology_screen.dart';
import '../screens/guided_topic_scoping_screen.dart';
import '../screens/my_notes_screen.dart';
import '../screens/new_notes_screen.dart';
import '../screens/plagiarism_check_screen.dart';
import '../screens/citation_generation_screen.dart';
import '../screens/library_screen.dart';
import '../screens/login_screen.dart';
import '../screens/saved_papers_screen.dart'; 

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/orbirag_logo.png',
                    width: 34,
                    height: 34,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.psychology_alt,
                      color: AppColors.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Orbirag",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.pop(context); // close drawer
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _item(
                    context,
                    icon: Icons.text_fields,
                    title: "Word Counter",
                    screen: const WordCounterScreen(),
                  ),
                  _item(
                    context,
                    icon: Icons.menu_book_outlined,
                    title: "Literature Retrieval",
                    screen: const LiteratureRetrievalScreen(),
                  ),
                  _item(
                    context,
                    icon: Icons.edit_note,
                    title: "Methodology Writing",
                    screen: const MethodologyScreen(),
                  ),
                  _item(
                    context,
                    icon: Icons.travel_explore,
                    title: "Guided Topic Scoping",
                    screen: const GuidedTopicScopingScreen(),
                  ),
                  _item(
                    context,
                    icon: Icons.note_alt_outlined,
                    title: "Notepad",
                    screen: const MyNotesScreen(),
                  ),
                  _item(
                    context,
                    icon: Icons.note_add,
                    title: "New Note",
                    screen: const NewNoteScreen(),
                  ),
                  _item(
                    context,
                    icon: Icons.bookmark_border,
                    title: "Saved Papers",
                    screen: const SavedPapersScreen(),
                  ),
                  _item(
                    context,
                    icon: Icons.shield_outlined,
                    title: "Plagiarism Check",
                    screen: const PlagiarismCheckScreen(),
                  ),
                  _item(
                    context,
                    icon: Icons.format_quote,
                    title: "Citation Generation",
                    screen: const CitationGenerationScreen(),
                  ),
                  _item(
                    context,
                    icon: Icons.library_books_outlined,
                    title: "Library",
                    screen: const LibraryScreen(),
                  ),
                ],
              ),
            ),

            // Logout
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                "Logout",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => _logout(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget screen,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
      ),
      onTap: () {
        Navigator.pop(context); // close drawer
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        );
      },
    );
  }

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "No",
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // close dialog

              // Sign out from Firebase
              await FirebaseAuthService.instance.signOut();

              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Yes"),
          ),
        ],
      ),
    );
  }
}