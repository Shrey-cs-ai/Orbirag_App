import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../services/papers_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/app_brand_title.dart';
import 'paper_reader_screen.dart';

class SavedPapersScreen extends StatefulWidget {
  const SavedPapersScreen({super.key});

  @override
  State<SavedPapersScreen> createState() => _SavedPapersScreenState();
}

class _SavedPapersScreenState extends State<SavedPapersScreen> {
  int _selectedIndex = 0;
  final PapersService _papersService = PapersService();
  final TextEditingController _searchController = TextEditingController();

  List<Paper> _filteredPapers = [];
  String _selectedFilter = 'All';
  bool _isSearching = false;
  bool _isLoading = true;

  final List<String> _filters = ['All', 'Reading', 'Analyzed', 'Unread'];

  @override
  void initState() {
    super.initState();
    _loadPapers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPapers() async {
    setState(() => _isLoading = true);
    await _papersService.initialize();
    if (!mounted) return;
    setState(() {
      _filteredPapers = _applyFilter(_papersService.papers);
      _isLoading = false;
    });
  }

  List<Paper> _applyFilter(List<Paper> all) {
    if (_selectedFilter == 'All') return List.from(all);
    return all.where((p) => p.status == _selectedFilter.toLowerCase()).toList();
  }

  void _filterPapers(String filter) {
    setState(() {
      _selectedFilter = filter;
      _filteredPapers = _applyFilter(_papersService.papers);
    });
  }

  void _searchPapers(String query) {
    setState(() {
      _filteredPapers = _papersService.searchPapers(query);
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredPapers = _applyFilter(_papersService.papers);
      }
    });
  }

  Future<void> _toggleFavorite(Paper paper) async {
    await _papersService.toggleFavorite(paper.id);
    if (!mounted) return;
    setState(() {
      _filteredPapers = _applyFilter(_papersService.papers);
    });
  }

  void _confirmDelete(Paper paper) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Paper'),
        content: Text('Remove "${paper.title}"?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              await _papersService.deletePaper(paper.id);
              if (!mounted) return;
              nav.pop();
              setState(() {
                _filteredPapers = _applyFilter(_papersService.papers);
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _openReader(Paper paper) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaperReaderScreen(paper: paper)),
    ).then((_) => _loadPapers()); // refresh on return
  }

  // ── Add Paper manually ────────────────────────────────────
  final _addFormKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _authorsCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  bool _isAddingPaper = false;

  void _showAddPaperDialog() {
    _titleCtrl.clear();
    _urlCtrl.clear();
    _authorsCtrl.clear();
    _categoryCtrl.clear();
    _yearCtrl.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Add Paper',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SingleChildScrollView(
          child: Form(
            key: _addFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(_titleCtrl, 'Title', 'Paper title',
                    validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null),
                const SizedBox(height: 12),
                _dialogField(_urlCtrl, 'URL', 'https://...',
                    keyboard: TextInputType.url),
                const SizedBox(height: 12),
                _dialogField(_authorsCtrl, 'Authors', 'Smith, J., et al.',
                    maxLines: 2,
                    validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null),
                const SizedBox(height: 12),
                _dialogField(_categoryCtrl, 'Category', 'e.g. EDUCATION'),
                const SizedBox(height: 12),
                _dialogField(_yearCtrl, 'Year', '2024',
                    keyboard: TextInputType.number),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          StatefulBuilder(
            builder: (_, setSt) => ElevatedButton(
              onPressed: () async {
                if (!_addFormKey.currentState!.validate()) return;
                setSt(() => _isAddingPaper = true);
                final messenger = ScaffoldMessenger.of(context);
                final paper = Paper(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: _titleCtrl.text.trim(),
                  authors: _authorsCtrl.text.trim(),
                  category: _categoryCtrl.text.trim().toUpperCase(),
                  year: _yearCtrl.text.trim(),
                  status: 'unread',
                  url: _urlCtrl.text.trim().isNotEmpty ? _urlCtrl.text.trim() : null,
                );
                await _papersService.addPaper(paper);
                if (!mounted) return;
                setSt(() => _isAddingPaper = false);
                Navigator.pop(ctx);
                await _loadPapers();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Paper added!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: _isAddingPaper
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : const Text('Add Paper'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String label,
    String hint, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.hintText, fontSize: 13),
            filled: true,
            fillColor: AppColors.inputFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusCounts = _papersService.getStatusCounts();

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
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style:
                    const TextStyle(fontSize: 16, color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search papers...',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: _searchPapers,
              )
            : const AppBrandTitle(),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: AppColors.textPrimary,
            ),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadPapers,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Saved Papers',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Your personal academic library.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 20),

                    // Filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filters.map((filter) {
                          final isSelected = _selectedFilter == filter;
                          final count = statusCounts[filter] ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('$filter ($count)'),
                              selected: isSelected,
                              onSelected: (_) => _filterPapers(filter),
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.white,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                              side: BorderSide(
                                color: isSelected ? AppColors.primary : AppColors.border,
                              ),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Paper list / empty state
                    if (_filteredPapers.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Column(
                            children: [
                              Icon(
                                Icons.bookmark_border,
                                size: 64,
                                color: AppColors.textSecondary.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'No papers match your search'
                                    : 'No saved papers yet',
                                style: const TextStyle(
                                    fontSize: 18, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'Try a different search term'
                                    : 'Papers you save from Literature Retrieval appear here',
                                style: const TextStyle(
                                    fontSize: 13, color: AppColors.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._filteredPapers.map((p) => _buildPaperCard(p)),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPaperDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Paper', style: TextStyle(color: Colors.white)),
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

  Widget _buildPaperCard(Paper paper) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: source · year + icons ──────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  '${paper.category.toUpperCase()} · ${paper.year}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  paper.isFavorite ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                  color: paper.isFavorite ? AppColors.error : AppColors.textSecondary,
                ),
                onPressed: () => _toggleFavorite(paper),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: AppColors.textSecondary),
                onPressed: () => _confirmDelete(paper),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // ── Title ──────────────────────────────────────
          Text(
            paper.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // ── Authors + abstract snippet ─────────────────
          Text(
            paper.abstract != null && paper.abstract!.isNotEmpty
                ? '${paper.authors} — ${paper.abstract}'
                : paper.authors,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),

          // ── Status-specific bottom row ─────────────────
          if (paper.status == 'read')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openReader(paper),
                icon: const Icon(Icons.arrow_forward, size: 16, color: AppColors.primary),
                label: const Text('Read',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
            )
          else if (paper.status == 'reading') ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: paper.progress,
                      backgroundColor: AppColors.border,
                      color: AppColors.sage,
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(paper.progress * 100).round()}% Read',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _openReader(paper),
                icon: const Icon(Icons.menu_book, size: 16),
                label: const Text('Continue'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lightPurple,
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
          ] else ...[
            // analyzed or unread
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _openReader(paper),
                icon: const Icon(Icons.play_arrow, size: 16),
                label: Text(paper.status == 'analyzed' ? 'Read Again' : 'Start Reading'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
