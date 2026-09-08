import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import 'notebook_llm_screen.dart';
import 'home_screen.dart';
import 'ori_chatbot_screen.dart';
import 'literature_retrieval_screen.dart';
import 'profile_screen.dart';

class PlagiarismCheckScreen extends StatefulWidget {
  const PlagiarismCheckScreen({super.key});

  @override
  State<PlagiarismCheckScreen> createState() => _PlagiarismCheckScreenState();
}

class _PlagiarismCheckScreenState extends State<PlagiarismCheckScreen> {
  int _currentIndex = 2; // Research tab

  void _onBottomNavTap(int index) {
    if (index == _currentIndex) return;

    Widget screen;
    switch (index) {
      case 0:
        screen = const HomeScreen();
        break;
      case 1:
        screen = const OriChatbotScreen();
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
      MaterialPageRoute(builder: (_) => screen),
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
          "Orbirag",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Image.asset(
              'assets/images/orbirag_logo.png',
              width: 28,
              height: 28,
              errorBuilder: (_, __, ___) => const Icon(Icons.auto_awesome),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotebookLLMScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Check Similarity",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Verify your document against billions of sources.",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Similarity Score Card
            _buildScoreCard(),
            const SizedBox(height: 16),

            // Info Box
            _buildInfoBox(),
            const SizedBox(height: 24),

            // Matched Text Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Matched Text",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text("12 Matches Found", style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Sample matched paragraph
            _buildMatchedText(),
            const SizedBox(height: 20),

            // Match Card
            _buildMatchCard(
              matchNumber: 3,
              percentage: "92%",
              words: "34 matching words",
              source: "Pedagogical Balancing in AI Systems",
              excerpt:
                  "...the primary challenge lies in balancing scale with personalized pedagogical...",
            ),
            const SizedBox(height: 20),

            // Report Summary
            _buildReportSummary(),
            const SizedBox(height: 24),

            const Center(
              child: Text(
                "Orbirag promotes academic integrity. Users are responsible for ensuring their work meets institutional guidelines.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
      ),
    );
  }

  // ===================== UI PARTS =====================

  Widget _buildScoreCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Similarity Score", style: TextStyle(fontWeight: FontWeight.w600)),
              Text("18%", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Low Similarity",
                  style: TextStyle(
                    color: Color(0xFF166534),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.verified, size: 16, color: AppColors.primaryLight),
              const SizedBox(width: 4),
              const Text(
                "AI Scanned",
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.primaryLight),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "A similarity match does not necessarily mean plagiarism. Review highlighted sections carefully to ensure proper citation.",
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchedText() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: RichText(
        text: const TextSpan(
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.5),
          children: [
            TextSpan(
              text:
                  "The integration of artificial intelligence in educational technologies has shown ",
            ),
            TextSpan(
              text:
                  "promising results. However, the reliance on automated systems for critical evaluation requires careful consideration of algorithmic bias. This is particularly",
              style: TextStyle(backgroundColor: Color(0xFFE0E7FF)),
            ),
            TextSpan(
              text:
                  " true in systems designed to assess student writing and originality.\n\nFurthermore, qualitative research suggests that ",
            ),
            TextSpan(
              text: "students often feel",
              style: TextStyle(backgroundColor: Color(0xFFFEE2E2)),
            ),
            TextSpan(text: " disconnected from feedback generated by machines."),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchCard({
    required int matchNumber,
    required String percentage,
    required String words,
    required String source,
    required String excerpt,
  }) {
    return Container(
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
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.primary,
                child: Text(
                  "$matchNumber",
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Text("Match #$matchNumber", style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  percentage,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(words, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          const Text(
            "SOURCE IDENTIFIED",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(source, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
          const SizedBox(height: 4),
          Text(
            excerpt,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),

          // Action chips
          Row(
            children: [
              _actionChip("Cite", Icons.format_quote),
              const SizedBox(width: 8),
              _actionChip("Paraphrase", Icons.auto_fix_high),
              const SizedBox(width: 8),
              _actionChip("Humanize", Icons.person_outline),
            ],
          ),
          const SizedBox(height: 12),

          // Tags
          Row(
            children: [
              _tag("Academic"),
              const SizedBox(width: 6),
              _tag("Simple"),
              const SizedBox(width: 6),
              _tag("Concise"),
            ],
          ),
          const SizedBox(height: 16),

          // AI Suggestion
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lightPurple,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: AppColors.purple),
                    SizedBox(width: 6),
                    Text(
                      "AI SUGGESTION",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.purple,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  "The main difficulty is finding an equilibrium between widespread implementation and tailored educational support.",
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Replace / Keep
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text("Replace"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text("Keep Original"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.visibility_off, size: 16),
              label: const Text("Exclude Match"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Report Summary",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatBox("Original Content", "82%")),
              const SizedBox(width: 12),
              Expanded(child: _buildStatBox("Total Words", "7,842")),
            ],
          ),
          const SizedBox(height: 20),

          // Download PDF
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Downloading PDF Report...")),
                );
              },
              icon: const Icon(Icons.download),
              label: const Text("Download PDF Report"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Run Check Again → Home
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              },
              child: const Text(
                "Run Check Again",
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _actionChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}