import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/chat_bubble.dart';
import 'voice_input_screen.dart';

class OriChatScreen extends StatefulWidget {
  const OriChatScreen({super.key});

  @override
  State<OriChatScreen> createState() => _OriChatScreenState();
}

class _OriChatScreenState extends State<OriChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [
    {
      "text": "Hello! I'm Ori, your academic research assistant. How can I help you with your literature review today?",
      "isUser": false,
      "time": "10:30 AM",
    },
    {
      "text": "I need help finding recent papers on machine learning in healthcare, specifically radiology.",
      "isUser": true,
      "time": "10:31 AM",
    },
    {
      "text": "Great topic! I'd recommend looking at recent advances in CNNs for MRI analysis and transformer models in CT scans. Would you like me to generate a search query or summarize key papers?",
      "isUser": false,
      "time": "10:31 AM",
    },
  ];

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        "text": text,
        "isUser": true,
        "time": "Just now",
      });
      _controller.clear();
    });

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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Orbirag",
      showBackButton: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.more_horiz),
          onPressed: () {},
        ),
      ],
      body: Column(
        children: [
          // Badge
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  style: TextStyle(fontSize: 12, color: AppColors.purple, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return ChatBubble(
                  message: msg['text'],
                  isUser: msg['isUser'],
                );
              },
            ),
          ),

          // Suggestion chips
          if (_messages.length <= 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSuggestionChip("How do I start a lit review?"),
                  _buildSuggestionChip("What is a research gap?"),
                ],
              ),
            ),

          // Input area
<<<<<<< HEAD
Container(
  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
  decoration: const BoxDecoration(
    color: AppColors.white,
    border: Border(top: BorderSide(color: AppColors.border)),
  ),
  child: Row(
    children: [
      Expanded(
        child: TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: "Type a message...",
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.cardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onSubmitted: (_) => _sendMessage(),
        ),
      ),
      const SizedBox(width: 8),

      // Mic Button → opens VoiceInputScreen
      CircleAvatar(
        backgroundColor: AppColors.primary,
        child: IconButton(
          icon: const Icon(Icons.mic, color: Colors.white, size: 20),
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VoiceInputScreen()),
            );

            if (result != null && result is String && result.trim().isNotEmpty) {
              setState(() {
                _controller.text = result;
              });
            }
          },
        ),
      ),
    ],
  ),
),
=======
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      hintStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.cardBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                 backgroundColor: AppColors.primary,
                child: IconButton(
                icon: const Icon(Icons.mic, color: Colors.white, size: 20),
                  onPressed: () {
                  Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VoiceInputScreen()),
                  );
                },
              ),
              ),
              ],
            ),
          ),
>>>>>>> 4914a4bcc9e59684a8050f37d9d23639907620bc
        ],
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
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}