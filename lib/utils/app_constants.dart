import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Static strings, route names and reusable text styles.
class AppConstants {
  AppConstants._();

  // ==================== APP INFO ====================
  static const String appName = 'Orbirag';
  static const String appTagline = 'AI-Powered Research Assistant';
  static const String oriName = 'Ori';

  // ==================== ROUTES ====================
  // Auth Routes
  static const String routeSplash = '/';
  static const String routeOnboarding = '/onboarding';
  static const String routeOpening = '/opening';
  static const String routeLanding = '/landing';
  static const String routeLogin = '/login';
  static const String routeSignup = '/signup';
  static const String routeForgotPassword = '/forgot-password';

  // Main App Routes
  static const String routeHome = '/home';
  static const String routeProfile = '/profile';
  static const String routeOriChat = '/ori-chat';
  static const String routeLiteratureRetrieval = '/literature-retrieval';
  static const String routeNotebookLLM = '/notebook-llm';
  static const String routeChatWithPdf = '/chat-with-pdf';
  static const String routeVoiceInput = '/voice-input';

  // Feature Routes
  static const String routeMyNotes = '/my-notes';
  static const String routeNewNote = '/new-note';
  static const String routeSavedPapers = '/saved-papers';
  static const String routeWordCounter = '/word-counter';
  static const String routePlagiarismCheck = '/plagiarism-check';
  static const String routeCitationGenerator = '/citation-generator';

  // ==================== BOTTOM NAVIGATION ====================
  static const List<Map<String, dynamic>> bottomNavItems = [
    {'icon': Icons.home_outlined, 'label': 'Home', 'route': routeHome},
    {'icon': Icons.chat_bubble_outline, 'label': 'Ori', 'route': routeOriChat},
    {'icon': Icons.search_outlined, 'label': 'Research', 'route': routeLiteratureRetrieval},
    {'icon': Icons.person_outline, 'label': 'Profile', 'route': routeProfile},
  ];

  // ==================== ONBOARDING ROLES ====================
  static const List<Map<String, dynamic>> roles = [
    {'label': 'PhD', 'icon': Icons.school_outlined},
    {'label': 'Masters/MBA', 'icon': Icons.workspace_premium_outlined},
    {'label': 'Undergraduate', 'icon': Icons.menu_book_outlined},
    {'label': 'Lecturer or Academic Staff', 'icon': Icons.co_present_outlined},
    {'label': 'Industry Professional', 'icon': Icons.business_center_outlined},
  ];

  // ==================== ORI CHAT SUGGESTIONS ====================
  static const List<String> suggestionChips = [
    'What is a research gap?',
    'How do I start a lit review?',
    'Help with methodology',
    'Citation styles',
    'Find research papers',
    'Write abstract',
  ];

  // ==================== PAPER STATUS FILTERS ====================
  static const List<String> paperFilters = ['All', 'Analyzed', 'Reading', 'Unread'];
  static const List<String> paperStatuses = ['unread', 'reading', 'analyzed'];

  // ==================== CITATION STYLES ====================
  static const List<String> citationStyles = [
    'APA 7',
    'MLA 9',
    'Chicago',
    'IEEE',
    'Harvard',
  ];

  // ==================== CITATION TABS ====================
  static const List<String> citationTabs = [
    'Upload Paper',
    'Paste URL',
    'Enter Manually',
  ];

  // ==================== DUMMY DATA ====================
  static const String samplePaperTitle =
      'Artificial Intelligence in Medical Diagnosis: A Review';
  static const String samplePaperFile = 'AI_Medical_Diagnosis.pdf';
  static const String sampleText =
      'The implications of this research are substancial for the field of '
      'cognitive behavioral therapy. Early interventions have shown a '
      'significant decrease in long-term symptom persistence.';

  // ==================== STORAGE KEYS ====================
  static const String keyHasSeenOnboarding = 'has_seen_onboarding';
  static const String keyUserRole = 'user_role';
  static const String keyRememberMe = 'remember_me';
  static const String keySavedPapers = 'saved_papers';
  static const String keyNotes = 'notes';
}

// ==================== TEXT STYLES ====================
class AppTextStyles {
  AppTextStyles._();

  // ==================== HEADINGS ====================
  static const TextStyle heading = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // ==================== SUBHEADINGS ====================
  static const TextStyle subheading = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle subheadingLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // ==================== BODY TEXT ====================
  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // ==================== INPUTS ====================
  static const TextStyle inputLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle inputText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle hintText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.hintText,
  );

  // ==================== BUTTONS ====================
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.3,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // ==================== LINKS ====================
  static const TextStyle link = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
    decoration: TextDecoration.underline,
  );

  // ==================== CHAT ====================
  static const TextStyle chatMessage = TextStyle(
    fontSize: 15,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle chatUserMessage = TextStyle(
    fontSize: 15,
    height: 1.4,
    color: Colors.white,
  );

  static const TextStyle chatTime = TextStyle(
    fontSize: 10,
    color: AppColors.textSecondary,
  );

  // ==================== STATS / NUMBERS ====================
  static const TextStyle statNumber = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle statLabel = TextStyle(
    fontSize: 11,
    color: AppColors.textSecondary,
  );

  // ==================== PAPER CARDS ====================
  static const TextStyle paperTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle paperCategory = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  static const TextStyle paperAuthors = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
    height: 1.3,
  );

  // ==================== NOTE CARDS ====================
  static const TextStyle noteTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle noteContent = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static const TextStyle noteDate = TextStyle(
    fontSize: 11,
    color: AppColors.hintText,
  );

  // ==================== CITATION ====================
  static const TextStyle citationTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle citationContent = TextStyle(
    fontSize: 14,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  // ==================== WORD COUNTER ====================
  static const TextStyle wordCounterHeader = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle wordCounterSubheader = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  static const TextStyle wordCounterNumber = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  // ==================== VOICE INPUT ====================
  static const TextStyle voiceStatus = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle voiceTranscript = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // ==================== ONBOARDING ====================
  static const TextStyle onboardingTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle onboardingSubtitle = TextStyle(
    fontSize: 15,
    color: AppColors.textSecondary,
  );

  static const TextStyle onboardingRole = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle onboardingRoleSelected = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );
}