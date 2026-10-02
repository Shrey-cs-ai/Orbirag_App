import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/app_brand_title.dart';
import '../models/analysis_result.dart';
import '../services/word_counter_api.dart';

class WordCounterScreen extends StatefulWidget {
  const WordCounterScreen({super.key});

  @override
  State<WordCounterScreen> createState() => _WordCounterScreenState();
}

class _WordCounterScreenState extends State<WordCounterScreen> {
  final TextEditingController _controller = TextEditingController();
  final WordCounterApi _api = WordCounterApi();

  int _selectedIndex = 0;
  Timer? _debounce;
  int _requestId = 0;

  // Backend state
  TextStats? _stats;
  List<Suggestion> _suggestions = [];
  bool _isAnalyzing = false;
  bool _hasError = false;
  final Set<String> _ignoredWords = {};

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  // Local instant estimate while typing
  int get _localWordCount {
    final text = _controller.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  void _onTextChanged() {
    setState(() {}); // Update local count instantly
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _analyze);
  }

  Future<void> _analyze() async {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      setState(() {
        _stats = null;
        _suggestions = [];
        _isAnalyzing = false;
      });
      return;
    }

    final requestId = ++_requestId;
    setState(() {
      _isAnalyzing = true;
      _hasError = false;
    });

    try {
      final result = await _api.analyze(
        text: text,
        ignoreWords: _ignoredWords.toList(),
      );

      if (!mounted || requestId != _requestId) return; // Drop stale request

      setState(() {
        _stats = result.stats;
        _suggestions = result.suggestions;
        _isAnalyzing = false;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _isAnalyzing = false;
        _hasError = true;
      });
    }
  }

  void _applySuggestion(Suggestion s) {
    final text = _controller.text;
    if (s.start < 0 || s.end > text.length || s.start >= s.end) return;

    final updated = text.replaceRange(s.start, s.end, s.replacement);
    _controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: s.start + s.replacement.length),
    );

    setState(() => _suggestions.removeWhere((x) => x.id == s.id));
    _analyze(); // Re-analyze after replacement
  }

  void _ignoreSuggestion(Suggestion s) {
    setState(() {
      _ignoredWords.add(s.original.toLowerCase());
      _suggestions.removeWhere((x) => x.id == s.id);
    });
  }

  void _clearText() {
    _controller.clear();
    setState(() {
      _stats = null;
      _suggestions = [];
    });
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: _controller.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text copied to clipboard'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pasteText() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      _controller.text = data!.text!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasText = _controller.text.isNotEmpty;
    final int wordCount = _stats?.words ?? _localWordCount;

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
        title: const AppBrandTitle(),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined, color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).pushNamed(AppConstants.routePaperOrbit),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Word Counter",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              "Check your words, grammar, and spelling.",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Text Area
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
                  TextField(
                    controller: _controller,
                    maxLines: 10,
                    minLines: 6,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "Paste or type your text here...",
                      hintStyle: TextStyle(color: AppColors.hintText, fontSize: 15),
                    ),
                    style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _actionButton(icon: Icons.copy, label: "Copy", onPressed: hasText ? _copyText : null),
                      _actionButton(icon: Icons.paste, label: "Paste", onPressed: _pasteText),
                      _actionButton(icon: Icons.clear, label: "Clear", onPressed: hasText ? _clearText : null),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Stats Cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('Words', wordCount.toString(), Icons.numbers, AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard('Chars', (_stats?.characters ?? _controller.text.length).toString(), Icons.text_fields, AppColors.purple),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard('Sentences', (_stats?.sentences ?? 0).toString(), Icons.short_text, AppColors.success),
                ),
              ],
            ),

            if (_isAnalyzing) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 2),
            ],

            if (_hasError) ...[
              const SizedBox(height: 12),
              const Text("Couldn't reach the server. Word count is still accurate.", style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],

            const SizedBox(height: 16),

            // AI Suggestions
            ..._suggestions.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildSuggestionCard(s),
            )),

            if (hasText && !_isAnalyzing && _suggestions.isEmpty && !_hasError)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
                    SizedBox(width: 8),
                    Text("No issues found.", style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
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

  Widget _actionButton({required IconData icon, required String label, required VoidCallback? onPressed}) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildSuggestionCard(Suggestion s) {
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
              const Icon(Icons.auto_awesome, size: 16, color: AppColors.purple),
              const SizedBox(width: 6),
              const Text("AI Suggestion", style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.purple)),
              const Spacer(),
              Text(s.type.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              children: [
                TextSpan(
                  text: s.original,
                  style: const TextStyle(color: AppColors.error, decoration: TextDecoration.lineThrough),
                ),
                const TextSpan(text: "  →  "),
                TextSpan(
                  text: s.replacement,
                  style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (s.message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(s.message, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton(
                onPressed: () => _applySuggestion(s),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text("Replace"),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => _ignoreSuggestion(s),
                child: const Text("Ignore", style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
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
                child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}