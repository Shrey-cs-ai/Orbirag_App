import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../widgets/app_scaffold.dart';
import 'voice_input_screen.dart'; // ← make sure this import exists

class ChatWithPdfScreen extends StatefulWidget {
  final List<Map<String, dynamic>> sources;

  const ChatWithPdfScreen({
    super.key,
    this.sources = const [],
  });

  @override
  State<ChatWithPdfScreen> createState() => _ChatWithPdfScreenState();
}

class _ChatWithPdfScreenState extends State<ChatWithPdfScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [
    {
      "isUser": true,
      "text": "What is the main objective of this study?",
    },
    {
      "isUser": false,
      "text":
          "Based on the paper, the main objective of this study is to evaluate the efficacy of machine learning models in early-stage diagnostic workflows.\n\nSpecifically, it aims to:\n• Compare deep learning algorithms against traditional diagnostic benchmarks.\n• Identify bottlenecks in clinical implementation of AI tools.\n• Propose a framework for integrating AI securely with existing electronic health records (EHR).",
      "source": "Page 3",
    },
  ];

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"isUser": true, "text": text});
      _controller.clear();
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      setState(() {
        _messages.add({
          "isUser": false,
          "text": "This is a sample response based on the analyzed paper. You can connect your real AI backend later.",
          "source": "Page 5",
        });
      });
      _scrollToBottom();
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
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get first source name (if available)
    final String paperName = widget.sources.isNotEmpty
        ? widget.sources.first["name"] ?? "Document"
        : "AI_Medical_Diagnosis.pdf";

    return AppScaffold(
      title: "Orbirag",
      showBackButton: true,
      actions: [
        IconButton(icon: const Icon(Icons.bolt_outlined), onPressed: () {}),
      ],
      body: Column(
        children: [
          // Paper header card
          Container(
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
                      child: const Icon(Icons.picture_as_pdf, color: Color(0xFFE11D48), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.circle, size: 8, color: AppColors.success),
                              SizedBox(width: 6),
                              Text(
                                "PAPER ANALYZED",
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            paperName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onPressed: () {},
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
                      Icon(Icons.chat_bubble_outline, size: 14, color: AppColors.purple),
                      SizedBox(width: 6),
                      Text(
                        "Chatting with this paper",
                        style: TextStyle(fontSize: 12, color: AppColors.purple, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              itemCount: _messages.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    children: [
                      const Icon(Icons.auto_awesome, size: 32, color: AppColors.primaryLight),
                      const SizedBox(height: 12),
                      const Text(
                        "Ready to explore",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "I've analyzed the document. Ask me anything or try a suggestion below.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text("TODAY", style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }

                final msg = _messages[index - 1];
                final isUser = msg["isUser"] as bool;

                if (isUser) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        msg["text"],
                        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                      ),
                    ),
                  );
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: AppColors.lightPurple,
                            child: Icon(Icons.auto_awesome, size: 14, color: AppColors.purple),
                          ),
                          SizedBox(width: 8),
                          Text("Orbirag AI", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                            Text(
                              msg["text"],
                              style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary),
                            ),
                            if (msg["source"] != null) ...[
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.cardBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.description_outlined, size: 13),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Source: ${msg["source"]}",
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 16),
                                    onPressed: () {},
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.thumb_up_outlined, size: 16),
                                    onPressed: () {},
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
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

          // Suggestion chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _suggestionChip("Summarize", Icons.notes),
                const SizedBox(width: 8),
                _suggestionChip("Key Findings", Icons.flag_outlined),
                const SizedBox(width: 8),
                _suggestionChip("Methodology", Icons.science_outlined),
              ],
            ),
          ),

          // Input area with Mic icon
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: AppColors.textSecondary),
                  onPressed: () {},
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Ask about this paper...",
                      hintStyle: const TextStyle(color: AppColors.hintText),
                      filled: true,
                      fillColor: AppColors.cardBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 6),

                // Mic Button → opens Voice Input Screen
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.cardBg,
                  child: IconButton(
                    icon: const Icon(Icons.mic, color: AppColors.primary, size: 22),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const VoiceInputScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 6),

                // Send Button
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionChip(String label, IconData icon) {
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
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}