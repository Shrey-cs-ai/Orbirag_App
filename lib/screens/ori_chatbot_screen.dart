import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
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
  final FocusNode _focusNode = FocusNode();

  bool _isTyping = false;
  int _selectedIndex = 1; // Ori is index 1

  final List<Map<String, dynamic>> _messages = [
    {
      "text": "Hi, I'm Ori 😊\nHow can I help you with your research today?",
      "isUser": false,
      "time": _getCurrentTime(),
    },
  ];

  // AI Response mapping
  final Map<String, String> _aiResponses = {
    'research gap':
        'A research gap is essentially an unanswered question or an unresolved problem in a specific field of study. It\'s the missing piece of the puzzle that existing literature hasn\'t covered yet.\n\nTo find one, you can start by reading recent systematic reviews in your area and looking closely at their "Recommendations for Future Research" sections.',
    'lit review':
        'To start a literature review:\n\n1️⃣ Define your research question\n2️⃣ Search for relevant papers using databases like Google Scholar, PubMed, or Scopus\n3️⃣ Read abstracts and select relevant papers\n4️⃣ Read full papers and take notes\n5️⃣ Organize by themes and identify gaps\n6️⃣ Write your review with proper citations\n\nWould you like me to help you with any of these steps?',
    'methodology':
        'For writing a methodology section:\n\n📌 Start with your research design (qualitative/quantitative/mixed)\n📌 Describe your participants/sample\n📌 Explain your data collection methods\n📌 Detail your analysis approach\n📌 Address ethical considerations\n📌 Justify your choices\n\nNeed help with any specific part?',
    'citation':
        'I can help with citations! Here are the most common styles:\n\n📝 APA 7th: (Author, Year)\n📝 MLA 9th: (Author Page)\n📝 Chicago: (Author Year, Page)\n📝 IEEE: [Number]\n📝 Harvard: (Author, Year)\n\nWhich style do you need?',
    'hello':
        'Hello! 👋 I\'m Ori, your AI research assistant. How can I help you with your academic work today? Feel free to ask me about:\n• Research gaps\n• Literature reviews\n• Methodology writing\n• Citation styles\n• Finding papers',
    'hi':
        'Hi there! 👋 I\'m Ori. What research topic are you working on? I can help you with:\n• Finding research gaps\n• Literature reviews\n• Methodology\n• Citations\n• And more!',
    'paper':
        'To find research papers:\n\n1️⃣ Use Google Scholar, PubMed, or Scopus\n2️⃣ Use keywords and Boolean operators (AND, OR, NOT)\n3️⃣ Check references of relevant papers\n4️⃣ Use citation tracking (who cited whom)\n5️⃣ Access through your university library\n\nI can help you refine your search strategy!',
    'abstract':
        'To write a strong abstract:\n\n📌 Background: What is the problem?\n📌 Objective: What did you do?\n📌 Methods: How did you do it?\n📌 Results: What did you find?\n📌 Conclusion: Why does it matter?\n\nKeep it concise (150-300 words) and include keywords!',
  };

  static String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Add user message
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

    // Simulate AI response
    Future.delayed(const Duration(milliseconds: 800), () {
      final response = _getAIResponse(text);
      setState(() {
        _messages.add({
          "text": response,
          "isUser": false,
          "time": _getCurrentTime(),
        });
        _isTyping = false;
      });
      _scrollToBottom();
    });
  }

  String _getAIResponse(String userMessage) {
    final lowerMsg = userMessage.toLowerCase();

    // Check for keywords
    for (final entry in _aiResponses.entries) {
      if (lowerMsg.contains(entry.key)) {
        return entry.value;
      }
    }

    // Default response
    return "That's a great question! 🤔 Let me think about that.\n\nI'm currently learning from research papers. Could you be more specific about what you'd like to know? For example:\n\n• Research gaps\n• Literature reviews\n• Methodology writing\n• Citation styles\n• Finding papers\n• Writing abstracts\n\nI'm here to help! 💪";
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
      setState(() {
        _controller.text = result;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        _sendMessage();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showSuggestions = _messages.length <= 2;

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
          IconButton(
            icon: const Icon(Icons.bolt_outlined, color: AppColors.textPrimary),
            onPressed: () {
              Navigator.of(context).pushNamed(AppConstants.routeNotebookLLM);
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

          // Messages
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
                return ChatBubble(
                  message: msg['text'],
                  isUser: msg['isUser'],
                  time: msg['time'],
                  showAvatar: true,
                );
              },
            ),
          ),

          // Suggestion Chips
          if (showSuggestions)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: AppConstants.suggestionChips.map((chip) {
                  return _buildSuggestionChip(chip);
                }).toList(),
              ),
            ),

          // Input Area
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Text Field with Mic
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
                          ),
                        ),
                        // Mic Button
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
                // Send Button
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
          final route = AppConstants.bottomNavItems[index]['route'] as String;
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
              color: Colors.black.withOpacity(0.04),
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
