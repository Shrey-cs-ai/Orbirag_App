import 'package:flutter/material.dart';

/// Orbirag palette — Deep Plum + Warm Ivory + Muted Coral + Sage
class AppColors {
  AppColors._();

  // ==================== PRIMARY (DEEP PLUM) ====================
  static const Color primary = Color(0xFF4A2545);        // Deep plum — main buttons, app bar
  static const Color primaryLight = Color(0xFF6E4468);   // Lighter plum
  static const Color primaryDark = Color(0xFF2D1530);    // Darker plum
  static const Color indigo = Color(0xFF5B3A5C);         // Alt plum

  // ==================== ACCENT ====================
  static const Color accentCyan = Color(0xFF7A9A7E);     // Replaced with sage
  static const Color purple = Color(0xFF6E4468);         // Plum accent (Ori AI)
  static const Color lightPurple = Color(0xFFF0E6EE);    // Soft plum tint
  static const Color micPurple = Color(0xFF5B2C5E);      // Voice mic
  static const Color oriColor = Color(0xFF6E4468);       // Ori chatbot

  // ==================== CORAL ====================
  static const Color coral = Color(0xFFE07856);          // Muted coral — CTAs, highlights
  static const Color coralLight = Color(0xFFF5C4B4);     // Light coral tint
  static const Color coralDark = Color(0xFFC75F3F);      // Darker coral

  // ==================== SAGE ====================
  static const Color sage = Color(0xFF7A9A7E);           // Sage green — success, accents
  static const Color sageLight = Color(0xFFD4E0D5);      // Light sage tint
  static const Color sageDark = Color(0xFF5C7A60);       // Darker sage

  // ==================== GRADIENTS ====================
  static const LinearGradient logoGradient = LinearGradient(
    colors: [coral, primary],
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

  static const LinearGradient coralGradient = LinearGradient(
    colors: [coral, coralDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ==================== BACKGROUND (WARM IVORY) ====================
  static const Color white = Colors.white;
  static const Color background = Color(0xFFFAF6F0);     // Warm ivory — main scaffold bg
  static const Color cardBg = Color(0xFFF5EFE7);         // Warm card fill
  static const Color inputFill = Color(0xFFF7F1E8);      // Input field background
  static const Color scaffoldGrey = Color(0xFFF8F3EC);   // Alt light grey
  static const Color listeningCardBg = Color(0xFFF5EDE6); // Voice listening card
  static const Color surface = Color(0xFFFAF6F0);        // Surface alias

  // ==================== TEXT ====================
  static const Color textPrimary = Color(0xFF2D1530);    // Deep plum text (headers, body)
  static const Color textSecondary = Color(0xFF6B5B68);  // Warm mauve-gray (subtitles)
  static const Color hintText = Color(0xFFB8A9B5);       // Placeholder text
  static const Color navInactive = Color(0xFFB8A9B5);    // Bottom nav inactive icons
  static const Color lowSimilarity = Color(0xFF7A9A7E);  // Sage (low similarity = good)

  // ==================== BORDER ====================
  static const Color border = Color(0xFFE8DFD5);         // Warm beige border

  // ==================== STATUS ====================
  static const Color success = Color(0xFF7A9A7E);        // Sage green
  static const Color error = Color(0xFFC7524B);          // Muted coral-red
  static const Color warning = Color(0xFFD89C58);        // Warm amber

  // ==================== SOCIAL COLORS ====================
  static const Color github = Color(0xFF24292E);
  static const Color linkedin = Color(0xFF0A66C2);
  static const Color google = Color(0xFFEA4335);

  // ==================== PROGRESS COLORS ====================
  static const Color progressColor1 = Color(0xFF4A2545); // Plum
  static const Color progressColor2 = Color(0xFFE07856); // Coral
  static const Color progressColor3 = Color(0xFF7A9A7E); // Sage

  // ==================== PLAGIARISM SCREEN ====================
  static const Color matchHighlightBlue = Color(0xFFE8E0F0);  // Light plum tint
  static const Color matchHighlightRed = Color(0xFFFBE5DC);   // Light coral tint
  static const Color lowSimilarityBg = Color(0xFFDDE8DE);     // Light sage bg
  static const Color lowSimilarityText = Color(0xFF4A6B4E);   // Dark sage text
  static const Color highMatchBg = Color(0xFFFBE5DC);         // Coral tint bg
  static const Color highMatchText = Color(0xFFB84C40);       // Dark coral text
  static const Color infoBoxBg = Color(0xFFF5EDE6);           // Warm info banner

  // ==================== PAPER ORBIT ====================
  static const Color pdfIconBg = Color(0xFFFBE5DC);           // Light coral tint
  static const Color pdfIconColor = Color(0xFFC7524B);        // Coral-red

  // ==================== DARK MODE (Future) ====================
  static const Color darkBackground = Color(0xFF1A0F1C);      // Very dark plum
  static const Color darkCardBg = Color(0xFF2D1E2E);          // Dark plum card
  static const Color darkTextPrimary = Color(0xFFF5EDE6);     // Warm ivory text
  static const Color darkTextSecondary = Color(0xFFB8A9B5);   // Muted mauve
  static const Color darkBorder = Color(0xFF4A3546);          // Dark plum border
}