import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class SocialButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;

  const SocialButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
          color: backgroundColor ?? AppColors.white,
        ),
        child: Center(
          child: icon,
        ),
      ),
    );
  }
}