import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:orbirag/screens/chat_with_pdf_screen.dart';
import 'firebase_options.dart';
import 'utils/app_colors.dart';
import 'utils/app_constants.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/opening_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/plagiarism_check_screen.dart';
import 'screens/voice_input_screen.dart';
import 'screens/ori_chatbot_screen.dart';
import 'screens/notebook_llm_screen.dart';
import 'screens/my_notes_screen.dart';
import 'screens/new_notes_screen.dart';
import 'screens/saved_papers_screen.dart';
import 'screens/word_counter_screen.dart';
import 'screens/library_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
      ),
      initialRoute: AppConstants.routeSplash,
      routes: {
        AppConstants.routeSplash: (context) => const SplashScreen(),
        AppConstants.routeOnboarding: (context) => const OnboardingScreen(),
        AppConstants.routeOpening: (context) => const OpeningScreen(),
        AppConstants.routeLanding: (context) => const LandingScreen(),
        AppConstants.routeLogin: (context) => const LoginScreen(),
        AppConstants.routeSignup: (context) => const SignupScreen(),
        AppConstants.routeProfile: (context) => const ProfileScreen(),
        AppConstants.routePlagiarismCheck: (context) => const PlagiarismCheckScreen(),
        AppConstants.routeVoiceInput: (context) => const VoiceInputScreen(),
        AppConstants.routeHome: (context) => const HomeScreen(),
        AppConstants.routeOriChat: (context) => const OriChatScreen(),
        AppConstants.routeSavedPapers: (context) => const SavedPapersScreen(),
        AppConstants.routeForgotPassword: (context) => const ForgotPasswordScreen(),
        AppConstants.routeNotebookLLM: (context) => const NotebookLLMScreen(),
        AppConstants.routeChatWithPdf: (context) => const ChatWithPdfScreen(),
        AppConstants.routeMyNotes: (context) => const MyNotesScreen(),
        AppConstants.routeWordCounter: (context) => const WordCounterScreen(),
        AppConstants.routeNewNote: (context) => const NewNoteScreen(),
        AppConstants.routeLibrary: (context) => const LibraryScreen(),
      },
    );
  }
}

// ==================== PLACEHOLDER SCREENS ====================

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const Center(child: Text('Home Screen')),
    );
  }
}

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: const Center(child: Text('Forgot Password Screen')),
    );
  }
}