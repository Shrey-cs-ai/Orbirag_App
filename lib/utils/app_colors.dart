import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary
  static const Color primary = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1B2A57);
  
  // Accent
  static const Color accentCyan = Color(0xFF3ED6D0);
  static const Color purple = Color(0xFF7C3AED);
  static const Color lightPurple = Color(0xFFF3E8FF);
  static const Color micPurple = Color(0xFF5B4FE9);

  static const LinearGradient logoGradient = LinearGradient(
    colors: [accentCyan, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Background
  static const Color white = Colors.white;
  static const Color background = Color(0xFFF8FAFC);
  static const Color cardBg = Color(0xFFF1F5F9);
  static const Color inputFill = Color(0xFFF2F3F7);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color hintText = Color(0xFFB0B3BD);
  static const Color navInactive = Color(0xFFAEB1BD);

  // Border
  static const Color border = Color(0xFFE2E8F0);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}