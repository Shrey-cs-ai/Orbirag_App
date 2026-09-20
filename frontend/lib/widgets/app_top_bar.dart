import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// Top bar used across the in-app screens (Home, Research, Voice input...).
/// Shows a drawer/menu icon on the left, the app title centered, and an
/// optional trailing action icon on the right.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onMenuTap;
  final IconData trailingIcon;
  final VoidCallback? onTrailingTap;

  const AppTopBar({
    super.key,
    required this.title,
    this.onMenuTap,
    this.trailingIcon = Icons.hub_outlined,
    this.onTrailingTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: AppColors.textPrimary),
            onPressed: onMenuTap,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: Icon(trailingIcon, color: AppColors.textSecondary),
            onPressed: onTrailingTap,
          ),
        ],
      ),
    );
  }
}
