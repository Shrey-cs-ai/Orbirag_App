import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_colors.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/citation_service.dart';
import '../services/plagiarism_service.dart';
import 'paper_orbit_screen.dart';
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
  final int _currentIndex = 2;

  final TextEditingController _documentController = TextEditingController();

  final PlagiarismService _service = PlagiarismService.instance;

  // Backend state
  bool _isChecking = false;
  PlagiarismResult? _result;

  // Selection + AI suggestion state
  PlagiarismMatch? _selectedMatch;
  String? _aiSuggestion;
  String _suggestionType = "";
  bool _isRewriting = false;

  @override
  void dispose() {
    _documentController.dispose();
    super.dispose();
  }

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

  // ===================== BACKEND CALLS =====================

  Future<void> _runCheck() async {
    final text = _documentController.text.trim();

    if (text.isEmpty) {
      _showMessage("Please paste some text first");
      return;
    }
    if (text.split(RegExp(r'\s+')).length < 20) {
      _showMessage("Please enter at least 20 words");
      return;
    }

    setState(() {
      _isChecking = true;
      _result = null;
      _selectedMatch = null;
      _aiSuggestion = null;
    });

    final result = await _service.check(text: text);

    if (!mounted) return;
    setState(() {
      _isChecking = false;
      _result = result;
    });

    if (result == null) {
      _showMessage("Check failed — is the backend running?");
    }
  }

  // ===================== ACTIONS =====================

  void _onCite() {
    if (_selectedMatch == null) {
      _showMessage("Please select a matched text first");
      return;
    }

    final match = _selectedMatch!;
    final citation = CitationService.instance.quickInTextFromSource(
      match.source,
      year: "2024",
    );

    final original = _documentController.text;
    if (original.contains(match.matchedText)) {
      final updated = original.replaceFirst(
        match.matchedText,
        "${match.matchedText} $citation",
      );
      setState(() {
        _documentController.text = updated;
        _aiSuggestion = null;
      });
      _showMessage("Citation added: $citation");
    } else {
      _showMessage("Could not locate match in text");
    }
  }

  Future<void> _onParaphrase() async {
    if (_selectedMatch == null) {
      _showMessage("Please select a matched text first");
      return;
    }

    setState(() {
      _isRewriting = true;
      _aiSuggestion = null;
      _suggestionType = "paraphrase";
    });

    final result = await _service.rewrite(
      text: _selectedMatch!.matchedText,
      mode: "paraphrase",
    );

    if (!mounted) return;
    setState(() {
      _isRewriting = false;
      _aiSuggestion = result;
    });

    if (result == null || result.isEmpty) {
      _showMessage("Paraphrase failed — check backend");
      setState(() => _suggestionType = "");
    }
  }

  Future<void> _onHumanize() async {
    if (_selectedMatch == null) {
      _showMessage("Please select a matched text first");
      return;
    }

    setState(() {
      _isRewriting = true;
      _aiSuggestion = null;
      _suggestionType = "humanize";
    });

    final result = await _service.rewrite(
      text: _selectedMatch!.matchedText,
      mode: "humanize",
    );

    if (!mounted) return;
    setState(() {
      _isRewriting = false;
      _aiSuggestion = result;
    });

    if (result == null || result.isEmpty) {
      _showMessage("Humanize failed — check backend");
      setState(() => _suggestionType = "");
    }
  }

  void _replaceWithSuggestion() {
    if (_selectedMatch == null || _aiSuggestion == null) return;

    final original = _documentController.text;
    final matchedText = _selectedMatch!.matchedText;

    if (original.contains(matchedText)) {
      final updated = original.replaceFirst(matchedText, _aiSuggestion!);
      setState(() {
        _documentController.text = updated;
        _aiSuggestion = null;
        _selectedMatch = null;
      });
      _showMessage("Text replaced successfully");
    } else {
      _showMessage("Could not locate match in text");
    }
  }

  void _keepOriginal() {
    setState(() => _aiSuggestion = null);
  }

  void _copyDocument() {
    Clipboard.setData(ClipboardData(text: _documentController.text));
    _showMessage("Copied to clipboard");
  }

  void _saveAsDraft() {
    _showMessage("Draft saved successfully");
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Color _scoreColor(double score) {
    if (score < 20) return const Color(0xFF166534);
    if (score < 50) return const Color(0xFFB45309);
    return const Color(0xFFB91C1C);
  }

  Color _scoreBg(double score) {
    if (score < 20) return const Color(0xFFDCFCE7);
    if (score < 50) return const Color(0xFFFEF3C7);
    return const Color(0xFFFEE2E2);
  }

  String _scoreLabel(double score) {
    if (score < 20) return "Low Similarity";
    if (score < 50) return "Moderate Similarity";
    return "High Similarity";
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    final matches = _result?.matches ?? [];

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
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaperOrbitScreen()),
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
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              "Verify your document against billions of sources.",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Document input + chips
            _buildDocumentPreview(),

            const SizedBox(height: 16),

            // Run Check button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isChecking ? null : _runCheck,
                icon: _isChecking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.search, size: 18),
                label: Text(
                  _isChecking ? "Analyzing..." : "Run Plagiarism Check",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            // Score card + info (only after result)
            if (_result != null) ...[
              const SizedBox(height: 20),
              _buildScoreCard(_result!),
              const SizedBox(height: 16),
              _buildInfoBox(),
              const SizedBox(height: 24),

              // Matched Text header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Matched Text",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${matches.length} Matches Found",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Selected match card
            if (_selectedMatch != null) ...[
              _buildSelectedMatchCard(),
              const SizedBox(height: 16),
            ],

            // AI suggestion
            if (_aiSuggestion != null) ...[
              _buildSuggestionCard(),
              const SizedBox(height: 16),
            ],

            // Copy + Save as Draft
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyDocument,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text("Copy"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveAsDraft,
                    icon: const Icon(Icons.bookmark_border, size: 18),
                    label: const Text("Save as Draft"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

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
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
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

  // ===================== WIDGETS =====================

  Widget _buildScoreCard(PlagiarismResult r) {
    final color = _scoreColor(r.score);
    final bg = _scoreBg(r.score);

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Similarity Score",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Text(
                "${r.score.toStringAsFixed(0)}%",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _scoreLabel(r.score),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.verified,
                  size: 16, color: AppColors.primaryLight),
              const SizedBox(width: 4),
              const Text("AI Scanned",
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          if (r.summary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              r.summary,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
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
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentPreview() {
    final matches = _result?.matches ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _documentController,
            maxLines: 8,
            minLines: 4,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: "Paste or write your text here...",
            ),
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          if (matches.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              "Tap a match below to select it for Cite / Paraphrase / Humanize",
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(matches.length, (i) {
                final m = matches[i];
                final isSelected =
                    _selectedMatch?.matchedText == m.matchedText;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMatch = m;
                      _aiSuggestion = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : const Color(0xFFE0E7FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      "Match #${i + 1}",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedMatchCard() {
    final match = _selectedMatch!;
    final pct = (match.similarity * 100).toStringAsFixed(0);

    return Container(
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
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.priority_high,
                    size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Text("Selected Match",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "$pct% Match",
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "\"${match.matchedText}\"",
            style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),
          Text(
            "Source: ${match.source}",
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (match.reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              match.reason,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _actionButton(
                "Cite",
                Icons.format_quote,
                _isRewriting ? null : _onCite,
              ),
              const SizedBox(width: 8),
              _actionButton(
                "Paraphrase",
                Icons.auto_fix_high,
                _isRewriting ? null : _onParaphrase,
              ),
              const SizedBox(width: 8),
              _actionButton(
                "Humanize",
                Icons.person_outline,
                _isRewriting ? null : _onHumanize,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightPurple.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 16, color: AppColors.purple),
              const SizedBox(width: 6),
              Text(
                _suggestionType == "paraphrase" ? "PARAPHRASED" : "HUMANIZED",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(_aiSuggestion!,
              style: const TextStyle(fontSize: 14, height: 1.4)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _replaceWithSuggestion,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text("Replace"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _keepOriginal,
                  child: const Text("Keep Original"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback? onTap) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}