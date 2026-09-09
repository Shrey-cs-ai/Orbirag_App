import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary
  static const Color primary = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1B2A57);
  static const Color indigo = Color(0xFF3B5BFE);
  
  // Accent
  static const Color accentCyan = Color(0xFF3ED6D0);
  static const Color purple = Color(0xFF7C3AED);
  static const Color lightPurple = Color(0xFFF3E8FF);
  static const Color micPurple = Color(0xFF5B4FE9);
  static const Color oriColor = Color(0xFF7C3AED);

   // ==================== GRADIENTS ====================
  static const LinearGradient logoGradient = LinearGradient(
    colors: [accentCyan, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient oriGradient = LinearGradient(
    colors: [purple, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Background
  static const Color white = Colors.white;
  static const Color background = Color(0xFFF8FAFC);
  static const Color cardBg = Color(0xFFF1F5F9);
  static const Color inputFill = Color(0xFFF2F3F7);
  static const Color scaffoldGrey = Color(0xFFF6F7FB);
  static const Color listeningCardBg = Color(0xFFF5F4FE); 
  static const Color surface = Color(0xFFF8FAFC);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color hintText = Color(0xFFB0B3BD);
  static const Color navInactive = Color(0xFFAEB1BD);
  static const Color lowSimilarity = Color(0xFF22C55E);

  // Border
  static const Color border = Color(0xFFE2E8F0);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Social Colors
  static const Color github = Color(0xFF24292E);
  static const Color linkedin = Color(0xFF0A66C2);
  static const Color google = Color(0xFFEA4335);

   // Progress Colors
  static const Color progressColor1 = Color(0xFF3B82F6);
  static const Color progressColor2 = Color(0xFF8B5CF6);
  static const Color progressColor3 = Color(0xFFEC4899);
  
  // ==================== PLAGIARISM SCREEN ====================
  static const Color matchHighlightBlue = Color(0xFFE0E7FF);  // Blue highlight
  static const Color matchHighlightRed = Color(0xFFFEE2E2);   // Red highlight
  static const Color lowSimilarityBg = Color(0xFFDCFCE7);     // Green badge bg
  static const Color lowSimilarityText = Color(0xFF166534);   // Green badge text
  static const Color highMatchBg = Color(0xFFFEE2E2);         // High match % bg
  static const Color highMatchText = Color(0xFFB91C1C);       // High match % text
  static const Color infoBoxBg = Color(0xFFEFF6FF);           // Info banner background

  // ==================== NOTEBOOK LLM ====================
  static const Color pdfIconBg = Color(0xFFFFE4E6);
  static const Color pdfIconColor = Color(0xFFE11D48);

  // ==================== DARK MODE (Future) ====================
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkCardBg = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF334155);
}

