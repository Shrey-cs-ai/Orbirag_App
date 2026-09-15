import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../services/search_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home_screen.dart';
import 'ori_chatbot_screen.dart';
import 'profile_screen.dart';

class LiteratureRetrievalScreen extends StatefulWidget {
  final String? initialQuery;

  const LiteratureRetrievalScreen({super.key, this.initialQuery});

  @override
  State<LiteratureRetrievalScreen> createState() =>
      _LiteratureRetrievalScreenState();
}

class _LiteratureRetrievalScreenState extends State<LiteratureRetrievalScreen> {
  final int _currentIndex = 2; // Research tab
  final SearchService _searchService = SearchService.instance;
  final TextEditingController _topicController = TextEditingController();

  // State
  SearchQuery? _builtQuery;
  List<SearchResult> _results = [];
  bool _isBuildingQuery = false;
  bool _isSearching = false;
  bool _hasSearched = false;
  String _selectedDateRange = '2015-2025';
  String _selectedDiscipline = 'All';

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _topicController.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _buildQuery());
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  // ==================== AI: BUILD QUERY ====================
  Future<void> _buildQuery() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      _showMessage('Please enter a topic , Keywords first');
      return;
    }

    setState(() => _isBuildingQuery = true);

    final query = await _searchService.buildSearchQuery(topic);

    if (!mounted) return;
    setState(() {
      _builtQuery = query;
      _isBuildingQuery = false;
    });

    if (query == null) {
      _showMessage('Could not build query. Please try again.');
    }
  }

  // ==================== AI: SEARCH + SUMMARIZE ====================
  Future<void> _runSearch() async {
    if (_builtQuery == null) {
      _showMessage('Please build a query first');
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _results = [];
    });

    try {
      // Step 1: Semantic + Vector search
      final results = await _searchService.searchPapers(
        query: _builtQuery!.booleanQuery.isNotEmpty
            ? _builtQuery!.booleanQuery
            : _topicController.text,
        dateRange: _selectedDateRange,
        discipline: _selectedDiscipline,
      );

      // Step 2: AI summarize in background
      final summarized = await _searchService.summarizeResults(results);

      if (!mounted) return;
      setState(() {
        _results = summarized;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      _showMessage('Search failed. Check your connection.');
    }
  }

  void _removeKeyword(String keyword) {
    if (_builtQuery == null) return;
    setState(() {
      _builtQuery!.keywords.remove(keyword);
    });
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ==================== NAVIGATION ====================
  void _onBottomNavTap(int index) {
    if (index == 2) return;

    switch (index) {
      case 0:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OriChatScreen()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
        break;
    }
  }

  // ==================== BUILD ====================
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
            icon: const Icon(Icons.menu, color: AppColors.textPrimary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          AppConstants.appName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_outlined, color: AppColors.textPrimary),
            onPressed: () {
              Navigator.pushNamed(context, AppConstants.routePaperOrbit);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            const Text(
              'Literature Retrieval',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Find relevant papers with AI-powered search',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            // TOPIC INPUT
            _buildTopicInput(),
            const SizedBox(height: 16),

            // KEYWORDS (shown after AI extraction)
            if (_builtQuery != null) ...[
              _buildKeywordSection(),
              const SizedBox(height: 16),
            ],

            // SCOPE
            _buildScopeSection(),
            const SizedBox(height: 16),

            // SEARCH BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSearching ? null : _runSearch,
                icon: _isSearching
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
                label: Text(_isSearching ? 'Searching...' : 'Run Search'),
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
            const SizedBox(height: 24),

            // RESULTS
            if (_hasSearched) _buildResultsSection(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
      ),
    );
  }

  // ==================== WIDGETS ====================

  Widget _buildTopicInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: AppColors.purple),
              SizedBox(width: 6),
              Text(
                'Research Topic',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _topicController,
            maxLines: 4,
            style: const TextStyle(fontSize: 14, height: 1.5),
            decoration: const InputDecoration(
              hintText: 'Paste your topic, question, or abstract here...',
              hintStyle: TextStyle(color: AppColors.hintText, fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              const Text(
                "We'll build an analytical query",
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const Spacer(),
              if (_isBuildingQuery)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.purple,
                  ),
                )
              else
                TextButton(
                  onPressed: _buildQuery,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Build Query',
                    style: TextStyle(
                      color: AppColors.purple,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeywordSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'KEYWORDS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _buildQuery,
                child: const Text(
                  'Re-extract',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.purple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _builtQuery!.keywords.map((keyword) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.drag_indicator,
                        size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      keyword,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _removeKeyword(keyword),
                      child: const Icon(Icons.close,
                          size: 14, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          if (_builtQuery!.synonyms.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'RELATED TERMS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _builtQuery!.synonyms.take(6).map((synonym) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.lightPurple,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+ $synonym',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.purple,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScopeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SCOPE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  value: _selectedDateRange,
                  items: ['2015-2025', '2020-2025', 'Last 5 years', 'All time'],
                  onChanged: (v) => setState(() => _selectedDateRange = v!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDropdown(
                  value: _selectedDiscipline,
                  items: ['All', 'Medicine', 'CS', 'Engineering', 'Education'],
                  onChanged: (v) => setState(() => _selectedDiscipline = v!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          items: items.map((e) {
            return DropdownMenuItem(value: e, child: Text(e));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_isSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                Icons.search_off,
                size: 60,
                color: AppColors.textSecondary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              const Text(
                'No papers found',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Try a different topic or broaden your scope',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_results.length} papers found',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ..._results.map((paper) => _buildPaperCard(paper)),
      ],
    );
  }

  Widget _buildPaperCard(SearchResult paper) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  paper.source,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              if (paper.citations > 0) ...[
                const Icon(Icons.format_quote,
                    size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 3),
                Text(
                  '${paper.citations}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            paper.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${paper.authors} · ${paper.year}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          if (paper.aiSummary.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.lightPurple.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome,
                      size: 12, color: AppColors.purple),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      paper.aiSummary,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final saved = await _searchService.savePaper(paper);
                    _showMessage(saved ? 'Saved to library!' : 'Save failed');
                  },
                  icon: const Icon(Icons.bookmark_border, size: 16),
                  label: const Text('Save', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, AppConstants.routePaperOrbit);
                  },
                  icon: const Icon(Icons.menu_book, size: 16),
                  label: const Text('Analyze', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.purple,
                    side: const BorderSide(color: AppColors.purple),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}