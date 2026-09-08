import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'Orbirag';
  static const String appTagline = 'AI-Powered Research Assistant';

  // Routes
  static const String routeSplash = '/';
  static const String routeOnboarding = '/onboarding';
  static const String routeLogin = '/login';
  static const String routeSignup = '/signup';
  static const String routeForgotPassword = '/forgot-password';
  static const String routeHome = '/home';
  static const String routeVoiceInput = '/voice-input';
  static const String routeProfile = '/profile';
  static const String routeOriChat = '/ori-chat';
  static const String routePlagiarismCheck = '/plagiarism-check';
  static const String routeOriChat = '/ori-chat';
  // Bottom Nav Items
  static const List<Map<String, dynamic>> bottomNavItems = [
    {'icon': Icons.home_outlined, 'label': 'Home', 'route': routeHome},
    {'icon': Icons.chat_bubble_outline, 'label': 'Ori', 'route': routeOriChat},
    {
      'icon': Icons.search_outlined,
      'label': 'Research',
      'route': '/literature-retrieval'
    },
    {'icon': Icons.person_outline, 'label': 'Profile', 'route': routeProfile},
  ];

  static const List<Map<String, dynamic>> roles = [
    {'label': 'PhD', 'icon': Icons.school_outlined},
    {'label': 'Masters/MBA', 'icon': Icons.workspace_premium_outlined},
    {'label': 'Undergraduate', 'icon': Icons.menu_book_outlined},
    {'label': 'Lecturer or Academic Staff', 'icon': Icons.co_present_outlined},
    {'label': 'Industry Professional', 'icon': Icons.business_center_outlined},
  ];
  // Add these routes
  static const String routeMyNotes = '/my-notes';
  static const String routeNewNote = '/new-note';

  static const List<String> suggestionChips = [
    'What is a research gap?',
    'How do I start a lit review?',
    'Help with methodology',
    'Citation styles',
    'Find research papers',
    'Write abstract',
  ];
}

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle heading = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle subheading = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle inputLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const TextStyle link = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );
}
