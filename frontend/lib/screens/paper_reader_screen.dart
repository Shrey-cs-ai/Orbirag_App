// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_colors.dart';
import '../services/papers_service.dart';
import '../services/library_service.dart';
import '../services/usage_service.dart';
import 'paper_orbit_screen.dart';
import 'citation_generation_screen.dart';

class PaperReaderScreen extends StatefulWidget {
  final Paper paper;
  const PaperReaderScreen({super.key, required this.paper});

  @override
  State<PaperReaderScreen> createState() => _PaperReaderScreenState();
}

class _PaperReaderScreenState extends State<PaperReaderScreen> {
  late double _progress;
  late String _status;
  bool _isSaving = false;

  // ── Bookmarks (mutable local copy refreshed from service) ─
  List<Bookmark> _bookmarks = [];

  // ── Reading-time tracker ──────────────────────────────────
  late final DateTime _sessionStart;
  Timer? _readingTimer;

  @override
  void initState() {
    super.initState();
    _progress = widget.paper.progress;
    _status = widget.paper.status;
    _bookmarks = List.from(widget.paper.bookmarks);
    _sessionStart = DateTime.now();

    // Auto-mark as reading on first open
    if (_status == 'unread') {
      _status = 'reading';
      WidgetsBinding.instance.addPostFrameCallback((_) => _saveProgress());
    }
  }

  @override
  void dispose() {
    _readingTimer?.cancel();
    _flushReadingTime();
    super.dispose();
  }

  void _flushReadingTime() {
    final seconds = DateTime.now().difference(_sessionStart).inSeconds;
    if (seconds > 0) {
      PapersService().updateReadingTime(widget.paper.id, seconds);
    }
  }

  // ── Save progress to backend ──────────────────────────────
  Future<void> _saveProgress() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    await PapersService().updateProgress(
      id: widget.paper.id,
      status: _status,
      progress: _progress,
    );
    if (mounted) setState(() => _isSaving = false);

    // Hook: paper_completed event
    if (_status == 'read' && _progress >= 1.0) {
      UsageService().recordEvent('paper_completed',
          extra: {'paperId': widget.paper.id, 'title': widget.paper.title});
    }
  }

  // ── Open URL: prefer PDF ──────────────────────────────────
  Future<void> _openUrl() async {
    // Prefer PDF URL, fall back to page URL
    final paper = widget.paper;
    final raw =
        (paper.pdfUrl != null && paper.pdfUrl!.isNotEmpty) ? paper.pdfUrl : paper.url;
    if (raw == null || raw.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No URL available for this paper')),
      );
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invalid URL')));
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!launched) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open URL')));
    }
  }

  String get _urlButtonLabel {
    final p = widget.paper;
    if (p.pdfUrl != null && p.pdfUrl!.isNotEmpty) return 'Open PDF';
    if (p.url != null && p.url!.isNotEmpty) return 'Open paper page';
    return '';
  }

  bool get _hasUrl {
    final p = widget.paper;
    return (p.pdfUrl != null && p.pdfUrl!.isNotEmpty) ||
        (p.url != null && p.url!.isNotEmpty);
  }

  // ── Bookmark helpers ──────────────────────────────────────
  Future<void> _addBookmark(Bookmark b) async {
    await PapersService().addBookmark(widget.paper.id, b);
    setState(() {
      _bookmarks = List.from(PapersService()
          .papers
          .firstWhere((p) => p.id == widget.paper.id,
              orElse: () => widget.paper)
          .bookmarks);
    });
  }

  Future<void> _removeBookmark(String bookmarkId) async {
    await PapersService().removeBookmark(widget.paper.id, bookmarkId);
    setState(() {
      _bookmarks.removeWhere((b) => b.id == bookmarkId);
    });
  }

  // ── Bookmark dialog ───────────────────────────────────────
  void _showBookmarkDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookmarkDialog(
        currentProgress: _progress,
        onSaveProgress: () {
          final label =
              'Progress: ${(_progress * 100).round()}%';
          final b = Bookmark(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            label: label,
            progress: _progress,
            type: BookmarkType.progress,
            createdAt: DateTime.now(),
          );
          _addBookmark(b);
        },
        onSaveNote: (label, quote) {
          final b = Bookmark(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            label: label,
            progress: _progress,
            type: BookmarkType.note,
            createdAt: DateTime.now(),
            quote: quote.isNotEmpty ? quote : null,
          );
          _addBookmark(b);
        },
      ),
    );
  }

  // ── Bookmark bottom sheet (list) ──────────────────────────
  void _showBookmarkSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BookmarkListSheet(
        paper: widget.paper,
        bookmarks: _bookmarks,
        onDelete: _removeBookmark,
        onTapBookmark: (progress) {
          setState(() => _progress = progress);
          Navigator.pop(ctx);
        },
        onSaveToLibrary: _saveNotesToLibrary,
      ),
    );
  }

  // ── Save notes to main Library ────────────────────────────
  Future<void> _saveNotesToLibrary() async {
    final notes = PapersService().exportNotes(widget.paper.id);
    if (notes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No notes to save yet.')),
      );
      return;
    }
    try {
      final item = LibraryItem(
        id: '',
        title: 'Notes: ${widget.paper.title}',
        description: notes,
        type: 'note',
        createdAt: DateTime.now(),
      );
      await LibraryService().addItem(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Notes saved to your main Library'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAbstract =
        widget.paper.abstract != null && widget.paper.abstract!.trim().isNotEmpty;
    final hasSummary =
        widget.paper.summary != null && widget.paper.summary!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.paper.title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Bookmark list icon
          IconButton(
            icon: Badge(
              isLabelVisible: _bookmarks.isNotEmpty,
              label: Text('${_bookmarks.length}'),
              child: const Icon(Icons.bookmarks_outlined, color: AppColors.primary),
            ),
            tooltip: 'Bookmarks & Notes',
            onPressed: _showBookmarkSheet,
          ),
          // Cite icon
          IconButton(
            icon: const Icon(Icons.format_quote, color: AppColors.primary),
            tooltip: 'Generate Citation',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CitationGeneratorScreen(),
              ),
            ),
          ),
          // Ask AI icon
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: AppColors.primary),
            tooltip: 'Ask AI (Paper Orbit)',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    PaperOrbitScreen(paperTitle: widget.paper.title),
              ),
            ),
          ),
          // Open URL
          if (_hasUrl)
            IconButton(
              icon: const Icon(Icons.open_in_new, color: AppColors.primary),
              tooltip: _urlButtonLabel,
              onPressed: _openUrl,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Scrollable content ─────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta
                  Text(
                    '${widget.paper.category.toUpperCase()} · ${widget.paper.year}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.paper.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.paper.authors,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 24),

                  // AI Summary
                  if (hasSummary) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.lightPurple.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.purple.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome,
                                  size: 14, color: AppColors.purple),
                              SizedBox(width: 6),
                              Text(
                                'AI Summary',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.purple,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.paper.summary!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                              height: 1.6,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Abstract
                  if (hasAbstract) ...[
                    const Text(
                      'Abstract',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.paper.abstract!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // No content fallback
                  if (!hasAbstract && !hasSummary) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.article_outlined,
                              size: 48, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          const Text(
                            'No abstract available for this paper.',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          if (_hasUrl) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _openUrl,
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: Text(_urlButtonLabel),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),

          // ── Progress panel (sticky at bottom) ─────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Bookmark chips ──────────────────────────
                if (_bookmarks.isNotEmpty) ...[
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _bookmarks.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final b = _bookmarks[i];
                        return GestureDetector(
                          onTap: () => setState(() => _progress = b.progress),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: b.type == BookmarkType.note
                                  ? AppColors.lightPurple
                                  : AppColors.cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: b.type == BookmarkType.note
                                    ? AppColors.purple
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  b.type == BookmarkType.note
                                      ? Icons.notes
                                      : Icons.bookmark,
                                  size: 12,
                                  color: b.type == BookmarkType.note
                                      ? AppColors.purple
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${(b.progress * 100).round()}%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: b.type == BookmarkType.note
                                        ? AppColors.purple
                                        : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Status label + percentage
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _statusDot(),
                        const SizedBox(width: 6),
                        Text(
                          _statusLabel(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (_isSaving)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.purple),
                          ),
                        const SizedBox(width: 6),
                        Text(
                          '${(_progress * 100).round()}% Read',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.purple,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Slider
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.border,
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withValues(alpha: 0.1),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _progress,
                    min: 0,
                    max: 1,
                    onChanged: (v) {
                      setState(() {
                        _progress = v;
                        if (v >= 1.0) {
                          _status = 'read';
                        } else if (v > 0) {
                          _status = 'reading';
                        }
                      });
                    },
                    onChangeEnd: (_) => _saveProgress(),
                  ),
                ),

                // Quick-mark buttons + Bookmark
                const SizedBox(height: 4),
                Row(
                  children: [
                    _markButton('Reading', 'reading', 0.01),
                    const SizedBox(width: 6),
                    _markButton('Analyzed', 'analyzed', 0.5),
                    const SizedBox(width: 6),
                    _markButton('Read', 'read', 1.0),
                    const SizedBox(width: 6),
                    // Bookmark button
                    GestureDetector(
                      onTap: _showBookmarkDialog,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        decoration: BoxDecoration(
                          color: AppColors.lightPurple,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.purple),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bookmark_add,
                                size: 14, color: AppColors.purple),
                            SizedBox(width: 3),
                            Text(
                              'Bookmark',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.purple),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusDot() {
    Color color;
    switch (_status) {
      case 'read':
        color = AppColors.success;
        break;
      case 'reading':
        color = AppColors.coral;
        break;
      case 'analyzed':
        color = AppColors.purple;
        break;
      default:
        color = AppColors.textSecondary;
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  String _statusLabel() {
    switch (_status) {
      case 'read':
        return 'Finished';
      case 'reading':
        return 'Reading';
      case 'analyzed':
        return 'Analyzed';
      default:
        return 'Not started';
    }
  }

  Widget _markButton(String label, String status, double progress) {
    final isActive = _status == status;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _status = status;
            _progress = progress;
          });
          _saveProgress();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Bookmark Dialog (bottom sheet)
// ─────────────────────────────────────────────────────────────

class _BookmarkDialog extends StatefulWidget {
  final double currentProgress;
  final VoidCallback onSaveProgress;
  final void Function(String label, String quote) onSaveNote;

  const _BookmarkDialog({
    required this.currentProgress,
    required this.onSaveProgress,
    required this.onSaveNote,
  });

  @override
  State<_BookmarkDialog> createState() => _BookmarkDialogState();
}

class _BookmarkDialogState extends State<_BookmarkDialog> {
  int _tab = 0; // 0 = progress marker, 1 = note
  final _noteCtrl = TextEditingController();
  final _quoteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    _quoteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Add Bookmark',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),

          // Tab selector
          Row(
            children: [
              _tabChip('📍 Progress Marker', 0),
              const SizedBox(width: 8),
              _tabChip('📝 Highlight / Note', 1),
            ],
          ),
          const SizedBox(height: 16),

          if (_tab == 0) ...[
            Text(
              'Save current reading position at ${(widget.currentProgress * 100).round()}%.',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  widget.onSaveProgress();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Progress marker saved!'),
                        backgroundColor: AppColors.success),
                  );
                },
                child: const Text('Save Progress Marker'),
              ),
            ),
          ] else ...[
            _inputField(_noteCtrl, 'Note *', 'What did you learn here?', maxLines: 3),
            const SizedBox(height: 10),
            _inputField(_quoteCtrl, 'Quote / Highlight (optional)',
                '"Quote from the paper..."', maxLines: 2),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  final label = _noteCtrl.text.trim();
                  if (label.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Note text is required.')),
                    );
                    return;
                  }
                  widget.onSaveNote(label, _quoteCtrl.text.trim());
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Note saved!'),
                        backgroundColor: AppColors.success),
                  );
                },
                child: const Text('Save Note'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tabChip(String label, int index) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _inputField(
      TextEditingController ctrl, String label, String hint,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: AppColors.hintText, fontSize: 13),
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
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Bookmark List Sheet
// ─────────────────────────────────────────────────────────────

class _BookmarkListSheet extends StatelessWidget {
  final Paper paper;
  final List<Bookmark> bookmarks;
  final void Function(String id) onDelete;
  final void Function(double progress) onTapBookmark;
  final VoidCallback onSaveToLibrary;

  const _BookmarkListSheet({
    required this.paper,
    required this.bookmarks,
    required this.onDelete,
    required this.onTapBookmark,
    required this.onSaveToLibrary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle + header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bookmarks & Notes (${bookmarks.length})',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onSaveToLibrary();
                      },
                      icon: const Icon(Icons.library_add, size: 16),
                      label: const Text('Save to Library'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(color: AppColors.border, height: 1),

          // List
          Expanded(
            child: bookmarks.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No bookmarks yet.\nUse the Bookmark button while reading.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: bookmarks.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: AppColors.border, height: 1),
                    itemBuilder: (ctx, i) {
                      final b = bookmarks[i];
                      return Dismissible(
                        key: Key(b.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          color: AppColors.error,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => onDelete(b.id),
                        child: InkWell(
                          onTap: () => onTapBookmark(b.progress),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: b.type == BookmarkType.note
                                        ? AppColors.lightPurple
                                        : AppColors.cardBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    b.type == BookmarkType.note
                                        ? Icons.notes
                                        : Icons.bookmark,
                                    size: 18,
                                    color: b.type == BookmarkType.note
                                        ? AppColors.purple
                                        : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        b.label,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (b.quote != null &&
                                          b.quote!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '"${b.quote}"',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                              fontStyle: FontStyle.italic),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 2),
                                      Text(
                                        'At ${(b.progress * 100).round()}% · ${b.createdAt.toLocal().toString().substring(0, 16)}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Export notes
          if (bookmarks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy Notes as Markdown'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final md =
                        PapersService().exportNotes(paper.id);
                    Clipboard.setData(ClipboardData(text: md));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Notes copied to clipboard!'),
                          backgroundColor: AppColors.success),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
