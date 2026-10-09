import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_colors.dart';
import '../services/papers_service.dart';

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

  @override
  void initState() {
    super.initState();
    _progress = widget.paper.progress;
    _status = widget.paper.status;

    // Auto-mark as reading on first open
    if (_status == 'unread') {
      _status = 'reading';
      WidgetsBinding.instance.addPostFrameCallback((_) => _saveProgress());
    }
  }

  Future<void> _saveProgress() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    await PapersService().updateProgress(
      id: widget.paper.id,
      status: _status,
      progress: _progress,
    );
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _openUrl() async {
    final raw = widget.paper.url;
    if (raw == null || raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No URL available for this paper')),
      );
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid URL')),
      );
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open URL')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAbstract =
        widget.paper.abstract != null && widget.paper.abstract!.trim().isNotEmpty;
    final hasSummary =
        widget.paper.summary != null && widget.paper.summary!.trim().isNotEmpty;
    final hasUrl = widget.paper.url != null && widget.paper.url!.isNotEmpty;

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
          if (hasUrl)
            IconButton(
              icon: const Icon(Icons.open_in_new, color: AppColors.primary),
              tooltip: 'Open full paper',
              onPressed: _openUrl,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Scrollable content ───────────────────────────
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
                        border: Border.all(color: AppColors.purple.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 14, color: AppColors.purple),
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
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          if (hasUrl) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _openUrl,
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('Open Full Paper'),
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

          // ── Progress panel (sticky at bottom) ────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                const SizedBox(height: 10),

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

                // Quick-mark buttons
                const SizedBox(height: 4),
                Row(
                  children: [
                    _markButton('Reading', 'reading', 0.01),
                    const SizedBox(width: 8),
                    _markButton('Analyzed', 'analyzed', 0.5),
                    const SizedBox(width: 8),
                    _markButton('Read', 'read', 1.0),
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
