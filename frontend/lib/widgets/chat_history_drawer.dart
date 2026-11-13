import 'package:flutter/material.dart';
import '../services/chat_history_service.dart';
import '../utils/app_colors.dart';

class ChatHistoryDrawer extends StatefulWidget {
  final String sessionType; // 'ori_chat' or 'paper_orbit'
  final String? activeConversationId;
  final ValueChanged<ChatConversationSummary> onSelectConversation;
  final VoidCallback onNewChat;
  final VoidCallback? onDeleteCurrent;

  const ChatHistoryDrawer({
    super.key,
    required this.sessionType,
    this.activeConversationId,
    required this.onSelectConversation,
    required this.onNewChat,
    this.onDeleteCurrent,
  });

  @override
  State<ChatHistoryDrawer> createState() => _ChatHistoryDrawerState();
}

class _ChatHistoryDrawerState extends State<ChatHistoryDrawer> {
  final ChatHistoryService _historyService = ChatHistoryService.instance;
  bool _isLoading = true;
  List<ChatConversationSummary> _conversations = [];
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final list = await _historyService.getHistory(
        sessionType: widget.sessionType,
      );
      if (mounted) {
        setState(() {
          _conversations = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteConversation(ChatConversationSummary conv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF22252D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Chat',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to delete "${conv.title}"?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingId = conv.id);
    final success = await _historyService.deleteConversation(conv.id);

    if (!mounted) return;
    setState(() {
      _deletingId = null;
      if (success) {
        _conversations.removeWhere((c) => c.id == conv.id);
      }
    });

    if (success) {
      if (widget.activeConversationId == conv.id &&
          widget.onDeleteCurrent != null) {
        widget.onDeleteCurrent!();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conversation deleted'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Map<String, List<ChatConversationSummary>> _groupConversations() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sevenDaysAgo = today.subtract(const Duration(days: 7));

    final Map<String, List<ChatConversationSummary>> groups = {
      'Today': [],
      'Yesterday': [],
      'Previous 7 Days': [],
      'Older': [],
    };

    for (final c in _conversations) {
      final date = c.updatedAt ?? c.createdAt ?? now;
      if (_isSameDay(date, today)) {
        groups['Today']!.add(c);
      } else if (_isSameDay(date, yesterday)) {
        groups['Yesterday']!.add(c);
      } else if (date.isAfter(sevenDaysAgo)) {
        groups['Previous 7 Days']!.add(c);
      } else {
        groups['Older']!.add(c);
      }
    }

    // Remove empty categories
    groups.removeWhere((key, value) => value.isEmpty);
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupConversations();
    final isPdf = widget.sessionType == 'paper_orbit';

    return Drawer(
      backgroundColor: const Color(0xFF17191E), // DeepSeek-style dark slate
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPdf ? Icons.auto_stories : Icons.chat_bubble_outline,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isPdf ? 'Paper Orbit History' : 'Ori Chat History',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // + New Chat Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onNewChat();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF23262F),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          gradient: AppColors.oriGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isPdf ? '+ New Paper Chat' : '+ New Chat',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6),
            const Divider(color: Color(0xFF282B33), height: 1),

            // Conversations List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : _conversations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 48,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No chat history yet',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Start a conversation to see it here',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          backgroundColor: const Color(0xFF23262F),
                          onRefresh: _loadHistory,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            itemCount: groups.length,
                            itemBuilder: (context, gIndex) {
                              final groupName = groups.keys.elementAt(gIndex);
                              final items = groups[groupName]!;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
                                    child: Text(
                                      groupName.toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF7E8492),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  ...items.map((conv) => _buildConversationItem(conv)),
                                ],
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationItem(ChatConversationSummary conv) {
    final isSelected = widget.activeConversationId == conv.id;
    final isDeleting = _deletingId == conv.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
                width: 1,
              )
            : null,
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          widget.sessionType == 'paper_orbit'
              ? Icons.description_outlined
              : Icons.chat_bubble_outline_rounded,
          size: 17,
          color: isSelected ? AppColors.primary : Colors.white60,
        ),
        title: Text(
          conv.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: isDeleting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.error,
                ),
              )
            : IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 17,
                  color: Colors.white38,
                ),
                tooltip: 'Delete',
                hoverColor: Colors.red.withValues(alpha: 0.1),
                splashRadius: 18,
                onPressed: () => _deleteConversation(conv),
              ),
        onTap: () {
          Navigator.of(context).pop();
          widget.onSelectConversation(conv);
        },
      ),
    );
  }
}

