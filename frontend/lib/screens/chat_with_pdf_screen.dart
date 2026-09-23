import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../services/ai_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/app_brand_title.dart';
import '../widgets/chat_bubble.dart';
import 'voice_input_screen.dart';

class ChatWithPdfScreen extends StatefulWidget {
  final String paperTitle;
  final String fileName;
  final String? paperId;

  const ChatWithPdfScreen({
    super.key,
    this.paperTitle = "Untitled Paper",
    this.fileName = "document.pdf",
    this.paperId,
  });

  @override
  State<ChatWithPdfScreen> createState() => _ChatWithPdfScreenState();
}

class _ChatWithPdfScreenState extends State<ChatWithPdfScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final AiService _aiService = AiService.instance;

  bool _isTyping = false;
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _messages = [
    {
      "isUser": false,
      "text":
          "Ready to explore\n\nI've analyzed the document. Ask me anything or try a suggestion below.",
      "time": "10:30 AM",
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour > 12
        ? now.hour - 12
        : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  // ============================================================
  // SEND
  // ============================================================
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isTyping) return;

    if (widget.paperId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No paper loaded. Please upload a PDF first.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _messages.add({
        "isUser": true,
        "text": text,
        "time": _getCurrentTime(),
      });
      _controller.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      // Build history for context
      final history = _messages
          .where((m) => m['isUser'] != null)
          .map((m) => {
                'text': m['text'] as String,
                'isUser': m['isUser'] as bool,
              })
          .toList();

      final result = await _aiService.chatWithPdf(
        paperId: widget.paperId!,
        question: text,
        history: history,
      );

      if (!mounted) return;
      final sources = result['sources'] as List?;
      final pageLabel = sources != null && sources.isNotEmpty
          ? "Page ${sources.first['page']}"
          : null;

      setState(() {
        _messages.add({
          "isUser": false,
          "text": result['response'] as String? ?? 'No response',
          "source": pageLabel,
          "time": _getCurrentTime(),
        });
        _isTyping = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add({
          "isUser": false,
          "text": "I couldn't reach the server. Please try again. 🔌",
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
    if (result != null && result is String && result.trim().isNotEmpty) {
      setState(() => _controller.text = result);
      Future.delayed(const Duration(milliseconds: 300), _sendMessage);
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () =>
              Navigator.of(context).pushReplacementNamed(AppConstants.routeHome),
        ),
        title: const AppBrandTitle(),
        actions: const [],
      ),
      body: Column(
        children: [
          _buildPaperHeader(),
          Expanded(child: _buildMessagesList()),
          _buildSuggestions(),
          _buildInputArea(),
        ],
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

  Widget _buildPaperHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4E6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.picture_as_pdf,
                    color: Color(0xFFE11D48), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.circle,
                            size: 8, color: AppColors.success),
                        SizedBox(width: 6),
                        Text("PAPER ANALYZED",
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.paperTitle,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.fileName,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.lightPurple,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 14, color: AppColors.purple),
                SizedBox(width: 6),
                Text("Chatting with this paper",
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.purple,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isTyping && index == _messages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.purple)),
                SizedBox(width: 8),
                Text('Analyzing paper...',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        final msg = _messages[index];
        final isUser = msg["isUser"] as bool;
        final text = msg["text"] as String;
        final time = msg["time"] as String?;
        final source = msg["source"] as String?;

        if (isUser) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: ChatBubble(
                message: text, isUser: true, time: time, showAvatar: true),
          );
        }

        return _buildAiMessage(text, time, source);
      },
    );
  }

  Widget _buildAiMessage(String text, String? time, String? source) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                    gradient: AppColors.oriGradient,
                    shape: BoxShape.circle),
                child: const Center(
                  child: Text('O',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              const Text("Orbirag AI",
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text,
                    style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.textPrimary)),
                if (source != null) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.description_outlined,
                                size: 13),
                            const SizedBox(width: 4),
                            Text("Source: $source",
                                style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (time != null) ...[
            const SizedBox(height: 4),
            Text(time, style: AppTextStyles.chatTime),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip("Summarize", Icons.notes),
            const SizedBox(width: 8),
            _chip("Key Findings", Icons.flag_outlined),
            const SizedBox(width: 8),
            _chip("Methodology", Icons.science_outlined),
            const SizedBox(width: 8),
            _chip("Conclusion", Icons.check_circle_outline),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon) {
    return GestureDetector(
      onTap: () {
        _controller.text = label;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
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
                        hintText: "Ask about this paper...",
                        hintStyle:
                            TextStyle(color: AppColors.textSecondary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.mic, color: AppColors.purple),
                    onPressed: _handleVoiceInput,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
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
    );
  }
}