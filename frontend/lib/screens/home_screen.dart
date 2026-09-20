import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/firebase_auth_service.dart';
import '../services/user_state_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import 'paper_orbit_screen.dart';
import 'voice_input_screen.dart';
import 'ori_chatbot_screen.dart';
import 'literature_retrieval_screen.dart';
import 'profile_screen.dart';
import 'guided_topic_scoping_screen.dart';
import 'citation_generation_screen.dart';
import 'plagiarism_check_screen.dart';
import 'saved_papers_screen.dart';
import 'my_notes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final int _currentIndex = 0;
  final UserStateService _userState = UserStateService();

  bool _isLoading = true;
  bool _isFirstTimeUser = true;
  String _firstName = 'Researcher';

  @override
  void initState() {
    super.initState();
    _loadUserState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==================== LOAD USER STATE ====================
  Future<void> _loadUserState() async {
    final hasStarted = await _userState.hasStartedResearch();
    final savedName = await _userState.getFirstName();

    final user = FirebaseAuthService.instance.currentUser;
    final displayName = user?.displayName ?? savedName;

    final firstName = displayName.split(' ').first;
    await _userState.saveFirstName(firstName);

    if (!mounted) return;
    setState(() {
      _isFirstTimeUser = !hasStarted;
      _firstName = firstName;
      _isLoading = false;
    });
  }

  // ==================== MARK RESEARCH STARTED ====================
  Future<void> _startResearch() async {
    await _userState.setHasStartedResearch(true);

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GuidedTopicScopingScreen()),
    );

    if (mounted) {
      setState(() => _isFirstTimeUser = false);
    }
  }

  // ==================== BOTTOM NAV HANDLER ====================
  // ✅ FIXED: Clean navigation for all bottom nav taps
  void _onBottomNavTap(int index) {
    // If tapping the current tab, do nothing
    if (index == _currentIndex) return;

    // Handle Home tap (shouldn't happen here since we're on Home, but just in case)
    if (index == 0) {
      return;
    }

    // Navigate to other screens
    Widget? screen;
    switch (index) {
      case 1:
        screen = const OriChatScreen();
        break;
      case 2:
        screen = const LiteratureRetrievalScreen();
        break;
      case 3:
        screen = const ProfileScreen();
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen!),
    );
  }

  // ==================== VOICE SEARCH ====================
  Future<void> _openVoiceSearch() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VoiceInputScreen()),
    );

    if (result != null && result is String && result.trim().isNotEmpty) {
      setState(() => _searchController.text = result);
      _performSearch(result);
    }
  }

  // ==================== PERFORM SEARCH ====================
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    // Mark user as active
    await _userState.setHasStartedResearch(true);

    if (!mounted) return;

    // Update state so returning user view shows
    setState(() => _isFirstTimeUser = false);

    // Navigate to literature retrieval
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiteratureRetrievalScreen(initialQuery: query),
      ),
    );
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.textPrimary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          "Orbirag",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.textPrimary,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaperOrbitScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: _isFirstTimeUser
                  ? _buildFirstTimeView(greeting)
                  : _buildReturningUserView(greeting),
            ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
      ),
    );
  }

  // ================================================================
  // VIEW 1: FIRST-TIME USER
  // ================================================================
  Widget _buildFirstTimeView(String greeting) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Greeting
        Text(
          "$greeting, $_firstName",
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Let's find your first research topic.",
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),

        // Search Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.search,
                  size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: "Search papers, topics, or authors",
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                        fontSize: 14, color: AppColors.hintText),
                  ),
                  onSubmitted: _performSearch,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.mic,
                    size: 20, color: AppColors.primary),
                onPressed: _openVoiceSearch,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Hint
        Row(
          children: [
            const Text(
              "Not sure what to search? ",
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            GestureDetector(
              onTap: _startResearch,
              child: const Text(
                "Try topic ideas →",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Hero Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF1B2A57)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A8A).withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Start Your First Research Topic",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Formulate your research question and find validated papers with step-by-step guidance.",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startResearch,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text(
                    "Start Topic Scoping",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Explore Section
        const Text(
          "Explore What Orbirag Can Do",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),

        _buildExploreItem(
          icon: Icons.search,
          iconColor: const Color(0xFF3B82F6),
          iconBg: const Color(0xFFDBEAFE),
          title: "Find papers in seconds",
          subtitle: "Semantic search across 200M+ academic sources",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const LiteratureRetrievalScreen()),
          ),
        ),
        const SizedBox(height: 10),
        _buildExploreItem(
          icon: Icons.menu_book,
          iconColor: const Color(0xFF8B5CF6),
          iconBg: const Color(0xFFEDE9FE),
          title: "Understand any paper",
          subtitle: "Summarize findings and methodologies",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PaperOrbitScreen()),
          ),
        ),
        const SizedBox(height: 10),
        _buildExploreItem(
          icon: Icons.edit_note,
          iconColor: const Color(0xFF10B981),
          iconBg: const Color(0xFFD1FAE5),
          title: "Guided review writer",
          subtitle: "Draft literature synthesis with auto-references",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyNotesScreen()),
          ),
        ),
        const SizedBox(height: 28),

        // Research Tools
        const Text(
          "Research Tools",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _toolCard(
              icon: Icons.travel_explore,
              title: "Guided Topic\nScoping",
              onTap: _startResearch,
            ),
            _toolCard(
              icon: Icons.format_quote,
              title: "Citation\nGenerator",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CitationGenerationScreen()),
              ),
            ),
            _toolCard(
              icon: Icons.shield_outlined,
              title: "Plagiarism\nCheck",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PlagiarismCheckScreen()),
              ),
            ),
            _toolCard(
              icon: Icons.bookmark_border,
              title: "Saved\nPapers",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SavedPapersScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ================================================================
  // VIEW 2: RETURNING USER
  // ================================================================
  Widget _buildReturningUserView(String greeting) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Greeting
        Text(
          "$greeting, $_firstName",
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Ready to advance your research?",
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),

        // Search Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: "Search paper by title or keywords...",
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                        fontSize: 14, color: AppColors.hintText),
                  ),
                  onSubmitted: _performSearch,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.mic,
                    size: 20, color: AppColors.primary),
                onPressed: _openVoiceSearch,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward,
                    size: 20, color: AppColors.primary),
                onPressed: () => _performSearch(_searchController.text),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Continue Research Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.play_circle_outline,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  const Text(
                    "CONTINUE RESEARCH",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.more_horiz, size: 18),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "Topic: Ethical AI in Healthcare",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    "Research Progress",
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  const Text(
                    "65%",
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  value: 0.65,
                  backgroundColor: AppColors.cardBg,
                  color: AppColors.primary,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Recommended
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "RECOMMENDED FOR YOU",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text(
                "View all",
                style: TextStyle(fontSize: 13, color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        SizedBox(
          height: 140,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _recommendedCard(
                title: "AI in Ethics (2023)",
                subtitle: "Matches your interest in Phil Tech",
                tag: "Highly Relevant",
              ),
              const SizedBox(width: 12),
              _recommendedCard(
                title: "Machine Learning (2022)",
                subtitle: "Essential for your research",
                tag: "Save for later",
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Research Tools
        const Text(
          "RESEARCH TOOLS",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 14),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _toolCard(
              icon: Icons.travel_explore,
              title: "Guided Topic\nScoping",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const GuidedTopicScopingScreen()),
              ),
            ),
            _toolCard(
              icon: Icons.format_quote,
              title: "Citation\nGenerator",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CitationGenerationScreen()),
              ),
            ),
            _toolCard(
              icon: Icons.shield_outlined,
              title: "Plagiarism\nCheck",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PlagiarismCheckScreen()),
              ),
            ),
            _toolCard(
              icon: Icons.bookmark_border,
              title: "Saved\nPapers",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SavedPapersScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ================================================================
  // SHARED WIDGETS
  // ================================================================

  Widget _buildExploreItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _recommendedCard({
    required String title,
    required String subtitle,
    required String tag,
  }) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text("Paper", style: TextStyle(fontSize: 10)),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            tag,
            style: const TextStyle(fontSize: 11, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _toolCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: AppColors.primary),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}