import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final bool showAvatar;
  final String? time;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.showAvatar = true,
    this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser && showAvatar) ...[
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
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.primary : AppColors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: isUser ? null : Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    message,
                    style: AppTextStyles.chatMessage.copyWith(
                      color: isUser ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (time != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    time!,
                    style: AppTextStyles.chatTime,
                  ),
                ],
              ],
            ),
          ),
          if (isUser && showAvatar) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
