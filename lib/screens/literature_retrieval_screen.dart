import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import 'notebook_llm_screen.dart';
import 'home_screen.dart';
import 'ori_chatbot_screen.dart';
import 'profile_screen.dart';

class LiteratureRetrievalScreen extends StatefulWidget {
  const LiteratureRetrievalScreen({super.key});

  @override
  State<LiteratureRetrievalScreen> createState() => _LiteratureRetrievalScreenState();
}

class _LiteratureRetrievalScreenState extends State<LiteratureRetrievalScreen> {
  final int _currentIndex = 2; // Research tab

  void _onBottomNavTap(int index) {
    if (index == _currentIndex) return;

    final screens = [
      const HomeScreen(),
      const OriChatScreen(),
      const LiteratureRetrievalScreen(),
      const ProfileScreen(),
    ];

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screens[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          "Literature Retrieval",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotebookLLMScreen()),
              );
            },
          ),
        ],
      ),
      body: const Center(
        child: Text(
          "Literature Retrieval Screen",
          style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
      ),
    );
  }
}
