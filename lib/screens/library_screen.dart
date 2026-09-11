import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../services/library_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import 'new_notes_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _selectedIndex = 0;
  final LibraryService _libraryService = LibraryService();
  final TextEditingController _searchController = TextEditingController();

  List<LibraryItem> _filteredItems = [];
  bool _isSearching = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    await _libraryService.initialize();
    setState(() {
      _filteredItems = _libraryService.items;
      _isLoading = false;
    });
  }

  void _searchItems(String query) {
    setState(() {
      _filteredItems = _libraryService.searchItems(query);
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredItems = _libraryService.items;
      }
    });
  }

  Future<void> _deleteItem(LibraryItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item.title}"?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _libraryService.deleteItem(item.id);
      await _loadItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item deleted'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _togglePin(LibraryItem item) async {
    await _libraryService.togglePin(item.id);
    await _loadItems();
  }

  Future<void> _openNewNote() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewNoteScreen()),
    );
    if (result == true) {
      await _loadItems();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Search notes, ideas, citations...',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: _searchItems,
              )
            : const Text(
                AppConstants.appName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: AppColors.textPrimary,
            ),
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.bolt_outlined, color: AppColors.textPrimary),
            onPressed: () {
              Navigator.of(context).pushNamed(AppConstants.routeNotebookLLM);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Personal Workspace Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person, size: 12, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'PERSONAL WORKSPACE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Title
                  const Text(
                    'My Library',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _searchItems,
                      decoration: const InputDecoration(
                        hintText: 'Search notes, ideas, citations, drafts...',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Recent Activity Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'RECENT ACTIVITY',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          'View All',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Items List
                  if (_filteredItems.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 60),
                          Icon(
                            Icons.library_books_outlined,
                            size: 64,
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isNotEmpty
                                ? 'No results found'
                                : 'Your library is empty',
                            style: const TextStyle(
                              fontSize: 18,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchController.text.isNotEmpty
                                ? 'Try a different search term'
                                : 'Save notes, ideas, and citations',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._filteredItems.map((item) => _buildLibraryItem(item)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewNote,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
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

  Widget _buildLibraryItem(LibraryItem item) {
    final typeInfo = _getTypeInfo(item.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isPinned
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
          width: item.isPinned ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: typeInfo['bgColor'] as Color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              typeInfo['icon'] as IconData,
              color: typeInfo['color'] as Color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type + Time
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: typeInfo['color'] as Color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.type.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _libraryService.getTimeAgo(item.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Title
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Description
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Actions (Pin + Delete)
          Column(
            children: [
              IconButton(
                icon: Icon(
                  item.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 18,
                  color: item.isPinned
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                onPressed: () => _togglePin(item),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: item.isPinned ? 'Unpin' : 'Pin',
              ),
              const SizedBox(height: 8),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.error,
                ),
                onPressed: () => _deleteItem(item),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getTypeInfo(String type) {
    switch (type.toLowerCase()) {
      case 'insight':
        return {
          'icon': Icons.lightbulb_outline,
          'color': const Color(0xFF3B82F6),
          'bgColor': const Color(0xFFDBEAFE),
        };
      case 'draft':
        return {
          'icon': Icons.edit_note,
          'color': const Color(0xFF10B981),
          'bgColor': const Color(0xFFD1FAE5),
        };
      case 'citation':
        return {
          'icon': Icons.format_quote,
          'color': const Color(0xFF8B5CF6),
          'bgColor': const Color(0xFFEDE9FE),
        };
      case 'idea':
        return {
          'icon': Icons.emoji_objects_outlined,
          'color': const Color(0xFFF59E0B),
          'bgColor': const Color(0xFFFEF3C7),
        };
      case 'note':
        return {
          'icon': Icons.sticky_note_2_outlined,
          'color': const Color(0xFFEF4444),
          'bgColor': const Color(0xFFFEE2E2),
        };
      case 'paper':
        return {
          'icon': Icons.description_outlined,
          'color': const Color(0xFF0EA5E9),
          'bgColor': const Color(0xFFE0F2FE),
        };
      default:
        return {
          'icon': Icons.article_outlined,
          'color': AppColors.primary,
          'bgColor': AppColors.cardBg,
        };
    }
  }
}
