import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../services/ai_service.dart';
import '../services/chat_history_service.dart';
import '../services/usage_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_history_drawer.dart';
import '../widgets/safe_chat_text.dart';
import 'voice_input_screen.dart';

class OriChatScreen extends StatefulWidget {
  const OriChatScreen({super.key});

  @override
  State<OriChatScreen> createState() => _OriChatScreenState();
}

class _OriChatScreenState extends State<OriChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isTyping = false;
  int _selectedIndex = 1;
  String? _activeConversationId;

  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _messages.add({
      "text": "Hi, I'm Ori 😊\nHow can I help you with your research today?",
      "isUser": false,
      "time": _getCurrentTime(),
    });
  }

  static String _getCurrentTime() {
    final now = DateTime.now();
    final hour =
        now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ---- Start a fresh chat ----
  void _startNewChat() {
    setState(() {
      _messages
        ..clear()
        ..add({
          "text":
              "Hi, I'm Ori 😊\nHow can I help you with your research today?",
          "isUser": false,
          "time": _getCurrentTime(),
        });
      _activeConversationId = null;
      AiService.instance.lastOriConversationId = null;
    });
    _controller.clear();
  }

  // ---- Load a past conversation ----
  Future<void> _loadConversation(ChatConversationSummary summary) async {
    setState(() => _isTyping = true);
    try {
      final detail =
          await ChatHistoryService.instance.getConversation(summary.id);
      if (!mounted) return;
      if (detail == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load conversation')),
        );
        return;
      }

      final msgs = detail['messages'] as List<ChatMessageItem>? ?? [];
      final newMessages = <Map<String, dynamic>>[
        {
          "text":
              "Hi, I'm Ori 😊\nHow can I help you with your research today?",
          "isUser": false,
          "time": _getCurrentTime(),
        },
      ];

      for (final m in msgs) {
        newMessages.add({
          "text": m.content,
          "isUser": m.role == 'user',
          "time": m.createdAt != null
              ? '${m.createdAt!.hour}:${m.createdAt!.minute.toString().padLeft(2, '0')}'
              : _getCurrentTime(),
        });
      }

      setState(() {
        _messages
          ..clear()
          ..addAll(newMessages);
        _activeConversationId = summary.id;
        AiService.instance.lastOriConversationId = summary.id;
        _isTyping = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTyping = false);
    }
  }

  // ---- SEND MESSAGE (via backend) ----
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isTyping) return;

    UsageService.recordEvent('ori_chatbot');

    // 1. Add user message to UI immediately
    setState(() {
      _messages.add({
        "text": text,
        "isUser": true,
        "time": _getCurrentTime(),
      });
      _controller.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      // 2. Build history to send to backend (exclude the welcome message)
      final history = _messages
          .where((m) => m['isUser'] != null)
          .map((m) => {
                'text': m['text'] as String,
                'isUser': m['isUser'] as bool,
              })
          .toList();

      // 3. Call the backend (which now also saves to DB)
      final result = await AiService.instance.chatFull(
        message: text,
        history: history,
        conversationId: _activeConversationId,
      );

      if (!mounted) return;

      final responseText = result['response'] as String? ?? '';
      final convId = result['conversation_id'] as String?;

      // 4. Add AI response to UI
      setState(() {
        _messages.add({
          "text": responseText,
          "isUser": false,
          "time": _getCurrentTime(),
        });
        _isTyping = false;
        if (convId != null) {
          _activeConversationId = convId;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add({
          "text":
              "I couldn't reach the server. Please check your connection and try again. 🔌",
          "isUser": false,
          "time": _getCurrentTime(),
        });
        _isTyping = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleVoiceInput() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VoiceInputScreen()),
    );
    if (result is String && result.trim().isNotEmpty) {
      _controller.text = result;
      Future.delayed(const Duration(milliseconds: 300), _sendMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showSuggestions = _messages.length <= 2;

    return Scaffold(
      backgroundColor: AppColors.background,
      // Left drawer: App navigation
      drawer: const AppDrawer(),
      // Right drawer: Chat History
      endDrawer: _ChatHistoryDrawerWrapper(
        activeConversationId: _activeConversationId,
        onSelectConversation: _loadConversation,
        onNewChat: _startNewChat,
        onDeleteCurrent: () {
          if (_activeConversationId != null) {
            _startNewChat();
          }
        },
      ),
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
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: AppColors.oriGradient,
                shape: BoxShape.circle,
              ),
              child: const Text(
                'O',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Ori Chat',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          // History icon
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.history_rounded,
                  color: AppColors.textPrimary),
              tooltip: 'Chat History',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.textPrimary,
            ),
            tooltip: 'Paper Orbit',
            onPressed: () {
              Navigator.of(context).pushNamed(AppConstants.routePaperOrbit);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // AI Badge
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.lightPurple,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 14, color: AppColors.purple),
                SizedBox(width: 6),
                Text(
                  "AI-assisted, source-grounded",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.purple,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == _messages.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 40),
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.purple,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Ori is thinking...',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final msg = _messages[index];
                final isUser = msg['isUser'] as bool;
                final message = msg['text'] as String;
                if (isUser) {
                  return ChatBubble(
                    message: message,
                    isUser: true,
                    time: msg['time'],
                    showAvatar: true,
                  );
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: AppColors.oriGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            'O',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                  bottomLeft: Radius.circular(4),
                                  bottomRight: Radius.circular(16),
                                ),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: SafeChatText(
                                message,
                                style: const TextStyle(
                                    fontSize: 15, height: 1.4),
                              ),
                            ),
                            if (msg['time'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                msg['time'] as String,
                                style: AppTextStyles.chatTime,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Suggestion chips (only when conversation is fresh)
          if (showSuggestions)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: AppConstants.suggestionChips
                    .map(_buildSuggestionChip)
                    .toList(),
              ),
            ),

          // Input area
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Text field + mic
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            maxLines: null,
                            minLines: 1,
                            textInputAction: TextInputAction.newline,
                            decoration: const InputDecoration(
                              hintText: "Type a message...",
                              hintStyle:
                                  TextStyle(color: AppColors.textSecondary),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.mic, color: AppColors.purple),
                          onPressed: _handleVoiceInput,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Send button
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _controller.text.trim().isNotEmpty
                          ? AppColors.purple
                          : AppColors.border,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      color: _controller.text.trim().isNotEmpty
                          ? Colors.white
                          : AppColors.textSecondary,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          final route =
              AppConstants.bottomNavItems[index]['route'] as String;
          Navigator.of(context).pushReplacementNamed(route);
        },
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () {
        _controller.text = text;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_awesome,
              size: 12,
              color: AppColors.purple,
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private wrapper so endDrawer can hold stateful ChatHistoryDrawer
// ---------------------------------------------------------------------------
class _ChatHistoryDrawerWrapper extends StatefulWidget {
  final String? activeConversationId;
  final ValueChanged<ChatConversationSummary> onSelectConversation;
  final VoidCallback onNewChat;
  final VoidCallback? onDeleteCurrent;

  const _ChatHistoryDrawerWrapper({
    this.activeConversationId,
    required this.onSelectConversation,
    required this.onNewChat,
    this.onDeleteCurrent,
  });

  @override
  State<_ChatHistoryDrawerWrapper> createState() =>
      _ChatHistoryDrawerWrapperState();
}

class _ChatHistoryDrawerWrapperState
    extends State<_ChatHistoryDrawerWrapper> {
  @override
  Widget build(BuildContext context) {
    return ChatHistoryDrawer(
      sessionType: 'ori_chat',
      activeConversationId: widget.activeConversationId,
      onSelectConversation: widget.onSelectConversation,
      onNewChat: widget.onNewChat,
      onDeleteCurrent: widget.onDeleteCurrent,
    );
  }
}
