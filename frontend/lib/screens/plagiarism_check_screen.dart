import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_colors.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/plagiarism_service.dart';
import '../services/library_service.dart';
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
  final PlagiarismService _service = PlagiarismService();

  List<PlagiarismMatch> _matches = [];
  int? _similarityScore;
  int? _aiLikelihoodScore;
  String? _aiLikelihoodExplanation;
  PlagiarismMatch? _selectedMatch;
  String? _aiSuggestion;
  String _suggestionType = '';
  String? _lastTargetText;
  bool _isChecking = false;
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


  String _targetText() {
    final sel = _documentController.selection;
    final text = _documentController.text;
    if (sel.isValid && sel.start != sel.end) {
      // There is an active selection
      final start =
          (sel.start < sel.end ? sel.start : sel.end).clamp(0, text.length);
      final end =
          (sel.start < sel.end ? sel.end : sel.start).clamp(0, text.length);
      final selected = text.substring(start, end);
      if (selected.trim().isNotEmpty) {
        return selected;
      }
    }
    // No selection — use the whole document (capped at 500 chars)
    final full = text.trim();
    return full.length > 500 ? full.substring(0, 500) : full;
  }

  Future<void> _runCheck() async {
    final text = _documentController.text.trim();
    if (text.isEmpty) {
      _showMessage('Please paste or write some text first');
      return;
    }

    setState(() {
      _isChecking = true;
      _aiSuggestion = null;
      _selectedMatch = null;
      _lastTargetText = null;
      _matches = [];
      _similarityScore = null;
      _aiLikelihoodScore = null;
      _aiLikelihoodExplanation = null;
    });

    try {
      final result = await _service.check(text);
      if (!mounted) return;
      setState(() {
        _similarityScore = result.similarityScore;
        _aiLikelihoodScore = result.aiLikelihoodScore;
        _aiLikelihoodExplanation = result.aiLikelihoodExplanation;
        _matches = result.matches;
        if (_matches.isNotEmpty) {
          _selectedMatch = _matches.first;
        }
        _isChecking = false;
      });
      _showMessage('${_matches.length} matches found');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isChecking = false);
      _showMessage('Check failed: $e');
    }
  }

  void _citeMatch(PlagiarismMatch match) {
    final original = _documentController.text;
    final matchedText = match.text;

    if (!original.contains(matchedText) &&
        !original.contains(matchedText.trim())) {
      _showMessage('Matched text not found in document (it may have been edited)');
      return;
    }

    final targetText =
        original.contains(matchedText) ? matchedText : matchedText.trim();

    // Format in-text citation: e.g. (Ganeju et al., 2026)
    final authorStr = match.sourceAuthor.isNotEmpty
        ? match.sourceAuthor
        : (match.sourceTitle.isNotEmpty ? match.sourceTitle : 'Unknown');
    final yearStr = match.sourceYear.isNotEmpty ? match.sourceYear : 'n.d.';
    final inTextCitation = '($authorStr, $yearStr)';

    String newText = original;
    final alreadyCited = original.contains('$targetText $inTextCitation') ||
        original.contains('$targetText$inTextCitation');

    if (!alreadyCited) {
      newText = newText.replaceFirst(targetText, '$targetText $inTextCitation');
    }

    // Full reference string from backend
    final fullReference = match.citationString.isNotEmpty
        ? match.citationString
        : '$authorStr ($yearStr). ${match.sourceTitle}.';

    // Add full reference to References section at bottom if not already present
    if (!newText.contains(fullReference)) {
      final refHeaderRegex =
          RegExp(r'\n\s*References:\s*', caseSensitive: false);
      if (refHeaderRegex.hasMatch(newText)) {
        newText = '$newText\n- $fullReference';
      } else {
        newText = '$newText\n\nReferences:\n- $fullReference';
      }
    }

    setState(() {
      _documentController.text = newText;
      _aiSuggestion = null;
    });

    if (alreadyCited && original.contains(fullReference)) {
      _showMessage('Citation already added');
    } else {
      _showMessage('Citation added: $inTextCitation');
    }
  }

  void _onCite() {
    if (_selectedMatch != null) {
      _citeMatch(_selectedMatch!);
    } else if (_matches.isNotEmpty) {
      _citeMatch(_matches.first);
    } else {
      _showMessage('Please select a matched text first');
    }
  }


  Future<void> _onParaphrase() async {
    if (_isRewriting) return;
    final target = _selectedMatch?.text ?? _targetText();
    if (target.trim().isEmpty) {
      _showMessage('Please enter or select text first');
      return;
    }
    setState(() {
      _isRewriting = true;
      _aiSuggestion = null;
      _lastTargetText = target;
    });
    try {
      debugPrint('[Plagiarism] calling paraphrase on target: $target');
      final result = await _service.paraphrase(target);
      debugPrint('[Plagiarism] result=$result');
      if (!mounted) return;
      setState(() {
        _aiSuggestion = result;
        _suggestionType = 'paraphrase';
        _isRewriting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRewriting = false);
      _showMessage('Paraphrase failed: $e');
    }
  }

  Future<void> _onHumanize() async {
    if (_isRewriting) return;
    final target = _selectedMatch?.text ?? _targetText();
    if (target.trim().isEmpty) {
      _showMessage('Please enter or select text first');
      return;
    }
    setState(() {
      _isRewriting = true;
      _aiSuggestion = null;
      _lastTargetText = target;
    });
    try {
      debugPrint('[Plagiarism] calling humanize on target: $target');
      final result = await _service.humanize(target);
      debugPrint('[Plagiarism] result=$result');
      if (!mounted) return;
      setState(() {
        _aiSuggestion = result;
        _suggestionType = 'humanize';
        _isRewriting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRewriting = false);
      _showMessage('Humanize failed: $e');
    }
  }

  void _replaceWithSuggestion() {
    if (_aiSuggestion == null) return;
    final original = _documentController.text;
    final target = _selectedMatch?.text ?? _lastTargetText;
    if (target != null && target.isNotEmpty && original.contains(target)) {
      setState(() {
        _documentController.text =
            original.replaceFirst(target, _aiSuggestion!);
        _aiSuggestion = null;
        _selectedMatch = null;
        _lastTargetText = null;
      });
      _showMessage('Text replaced successfully');
    } else if (target != null &&
        target.isNotEmpty &&
        original.contains(target.trim())) {
      setState(() {
        _documentController.text =
            original.replaceFirst(target.trim(), _aiSuggestion!);
        _aiSuggestion = null;
        _selectedMatch = null;
        _lastTargetText = null;
      });
      _showMessage('Text replaced successfully');
    } else {
      setState(() {
        _documentController.text = _aiSuggestion!;
        _aiSuggestion = null;
        _selectedMatch = null;
        _lastTargetText = null;
      });
      _showMessage('Text replaced successfully');
    }
  }

  void _keepOriginal() => setState(() {
        _aiSuggestion = null;
        _lastTargetText = null;
      });

  void _copyDocument() {
    Clipboard.setData(ClipboardData(text: _documentController.text));
    _showMessage('Copied to clipboard');
  }

  Future<void> _saveAsDraft() async {
    final text = _documentController.text.trim();
    if (text.isEmpty) {
      _showMessage('Nothing to save — enter some text first');
      return;
    }

    final title = text.length > 60 ? '${text.substring(0, 60)}...' : text;

    try {
      await LibraryService().addItem(LibraryItem(
        id: '',
        title: title,
        description: text.length > 200 ? '${text.substring(0, 200)}...' : text,
        type: 'draft',
        createdAt: DateTime.now(),
      ));
      if (!mounted) return;
      _showMessage('✅ Saved to Library');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Save failed: $e');
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
          'Orbirag',
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
              'Check Similarity',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Verify your document against billions of sources.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            _buildDocumentPreview(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isChecking ? null : _runCheck,
                icon: _isChecking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(
                  _isChecking ? 'Analyzing…' : 'Run Similarity Check',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_similarityScore != null) ...[
              const SizedBox(height: 20),
              _buildScoresSection(),
              const SizedBox(height: 16),
              _buildInfoBox(),
              const SizedBox(height: 12),
              _buildActionBar(),
              const SizedBox(height: 20),
              _buildMatchedSourcesSection(),
            ],
            if (_aiSuggestion != null) ...[
              const SizedBox(height: 16),
              _buildSuggestionCard(),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyDocument,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveAsDraft,
                    icon: const Icon(Icons.bookmark_border, size: 18),
                    label: const Text('Save as Draft'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                  'Run Check Again',
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
                'Orbirag promotes academic integrity. Users are responsible for ensuring their work meets institutional guidelines.',
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

  Widget _buildScoresSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildScoreCardItem(
                title: 'Overall Similarity',
                score: '$_similarityScore%',
                subtitle: 'Matched against sources',
                icon: Icons.find_in_page_outlined,
                color: (_similarityScore ?? 0) > 40
                    ? const Color(0xFFEF4444)
                    : ((_similarityScore ?? 0) > 15
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF10B981)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildScoreCardItem(
                title: 'AI-Likelihood',
                score: '$_aiLikelihoodScore%',
                subtitle: 'Probabilistic AI indicator',
                icon: Icons.psychology_outlined,
                color: (_aiLikelihoodScore ?? 0) > 50
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI detection is probabilistic and should not be treated as definitive proof.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        if (_aiLikelihoodExplanation != null &&
            _aiLikelihoodExplanation!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.psychology, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _aiLikelihoodExplanation!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScoreCardItem({
    required String title,
    required String score,
    required String subtitle,
    required IconData icon,
    required Color color,
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
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            score,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
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
              'Similarity is measured against abstracts of papers retrieved from Semantic Scholar. This is an educational tool — for institutional-grade results, consult Turnitin or iThenticate.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _documentController,
        maxLines: 8,
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Paste or write your text here…',
        ),
        style: const TextStyle(fontSize: 14, height: 1.5),
      ),
    );
  }


  Widget _buildActionBar() {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _actionButton(
                'Cite',
                Icons.format_quote,
                _onCite,
              ),
              const SizedBox(width: 8),
              _actionButton(
                'Paraphrase',
                Icons.auto_fix_high,
                _onParaphrase,
                isHighlighted: true,
              ),
              const SizedBox(width: 8),
              _actionButton(
                'Humanize',
                Icons.person_outline,
                _onHumanize,
              ),
            ],
          ),
          if (_isRewriting) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ],
      ),
    );
  }

  Widget _buildMatchedSourcesSection() {
    if (_matches.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'No matching sources found. Similarity is low!',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Matched Sources (${_matches.length})',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (_selectedMatch != null)
              TextButton(
                onPressed: () => setState(() => _selectedMatch = null),
                child: const Text('Clear selection', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ..._matches.map((match) {
          final isSelected = _selectedMatch?.id == match.id;
          final authorDisplay = match.sourceAuthor.isNotEmpty
              ? match.sourceAuthor
              : 'Unknown Author';
          final yearDisplay =
              match.sourceYear.isNotEmpty ? match.sourceYear : 'n.d.';
          final possibleSourceText =
              'Possible source: $authorDisplay, $yearDisplay';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.05)
                  : AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${match.similarityPercentage}% Similarity',
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMatch = isSelected ? null : match;
                          _aiSuggestion = null;
                        });
                      },
                      child: Text(
                        isSelected ? 'Selected' : 'Select for Paraphrase',
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '"${match.text}"',
                  style: const TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  possibleSourceText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                if (match.sourceTitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    match.sourceTitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => _citeMatch(match),
                    icon: const Icon(Icons.format_quote, size: 16),
                    label: const Text(
                      'Cite this match',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
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
              const Icon(Icons.auto_awesome, size: 16, color: AppColors.purple),
              const SizedBox(width: 6),
              Text(
                _suggestionType == 'paraphrase' ? 'PARAPHRASED' : 'HUMANIZED',
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
                  label: const Text('Replace'),
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
                  child: const Text('Keep Original'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool isHighlighted = false,
  }) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    return Expanded(
      child: isHighlighted
          ? ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 16),
              label: Text(label, style: const TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                elevation: 0,
                shape: shape,
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 16),
              label: Text(label, style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: shape,
              ),
            ),
    );
  }
}
