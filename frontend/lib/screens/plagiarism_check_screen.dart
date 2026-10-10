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

  // Backend state
  List<PlagiarismMatch> _matches = [];
  String _similarityScore = '';
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

  // ===================== ACTIONS =====================

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
      _similarityScore = '';
    });

    try {
      final result = await _service.check(text);
      if (!mounted) return;
      setState(() {
        _similarityScore = result.similarityScore;
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

  Future<void> _onCite() async {
    if (_isRewriting) return;
    final target = _selectedMatch?.text ?? _targetText();
    if (target.trim().isEmpty) {
      _showMessage('Please enter or select text first');
      return;
    }
    setState(() => _isRewriting = true);
    try {
      final source = _selectedMatch?.source ?? 'Unknown source';
      final year = _selectedMatch?.year ?? '2023';
      debugPrint('[Plagiarism] calling cite source=$source, year=$year');
      final citation = await _service.cite(source, year);
      debugPrint('[Plagiarism] result=$citation');
      if (!mounted) return;
      final original = _documentController.text;
      if (_selectedMatch != null && original.contains(target)) {
        // Replace inline (existing behavior)
        setState(() {
          _documentController.text =
              original.replaceFirst(target, '$target $citation');
          _aiSuggestion = null;
          _isRewriting = false;
        });
      } else if (_selectedMatch != null && original.contains(target.trim())) {
        setState(() {
          _documentController.text = original.replaceFirst(
              target.trim(), '${target.trim()} $citation');
          _aiSuggestion = null;
          _isRewriting = false;
        });
      } else {
        // Append to the end
        setState(() {
          _documentController.text =
              original.isEmpty ? citation : '$original\n\n$citation';
          _aiSuggestion = null;
          _isRewriting = false;
        });
      }
      _showMessage('Citation added: $citation');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRewriting = false);
      _showMessage('Cite failed: $e');
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
      _showMessage('✅ Saved to library');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Save failed: $e');
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ===================== UI =====================

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
            if (_similarityScore.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildScoreCard(),
              const SizedBox(height: 16),
              _buildInfoBox(),
              const SizedBox(height: 12),
              _buildActionBar(),
              const SizedBox(height: 24),
            ],
            if (_matches.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Matched Text',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_matches.length} Matches Found',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            if (_matches.isNotEmpty) const SizedBox(height: 12),
            if (_matches.isNotEmpty) _buildMatchesList(),
            if (_selectedMatch != null) ...[
              const SizedBox(height: 20),
              _buildSelectedMatchCard(),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Similarity Score',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Text(
                _similarityScore,
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.verified, size: 16, color: AppColors.primaryLight),
              SizedBox(width: 4),
              Text(
                'AI Scanned',
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
              'A similarity match does not necessarily mean plagiarism. Review highlighted sections carefully to ensure proper citation.',
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

  Widget _buildMatchesList() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _matches.map((match) {
        final isSelected = _selectedMatch?.id == match.id;
        return GestureDetector(
          onTap: () {
            debugPrint('[Plagiarism] tapped match id=${match.id}');
            setState(() {
              _selectedMatch = isSelected ? null : match;
              _aiSuggestion = null;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : const Color(0xFFE0E7FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
              ),
            ),
            child: Text(
              'Match #${match.id} · ${match.percentage}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
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

  Widget _buildSelectedMatchCard() {
    final match = _selectedMatch!;
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
                child: Text(
                  '${match.id}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Text('Match #${match.id}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${match.percentage} Match',
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
          Text('"${match.text}"',
              style:
                  const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          Text(
            'Source: ${match.source} (${match.year})',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _actionButton('Cite', Icons.format_quote, _onCite),
              const SizedBox(width: 8),
              _actionButton('Paraphrase', Icons.auto_fix_high, _onParaphrase),
              const SizedBox(width: 8),
              _actionButton('Humanize', Icons.person_outline, _onHumanize),
            ],
          ),
          if (_isRewriting) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
          ],
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
