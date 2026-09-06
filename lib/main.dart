import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'utils/app_colors.dart';
import 'utils/app_constants.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/saved_paper_screen.dart';
import 'screens/notebook_llm_screen.dart';
import 'screens/chat_with_pdf_screen.dart';
import 'screens/ori_chatbot_screen.dart';
import 'screens/voice_input_screen.dart';
import 'screens/plagarism_check_screen.dart';
import 'screens/citation_generation_screen.dart';
import 'screens/word_counter_screen.dart';
import 'screens/my_notes_screen.dart';
import 'screens/new_notes_screen.dart';

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
        AppConstants.routeLogin: (context) => const LoginScreen(),
        AppConstants.routeSignup: (context) => const SignupScreen(),
        AppConstants.routeHome: (context) => const HomeScreen(),
        AppConstants.routeForgotPassword: (context) => const ForgotPasswordScreen(),
        AppConstants.routeVoiceInput: (context) => const VoiceInputScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/saved-papers': (context) => const SavedPapersScreen(),
        '/notebook-llm': (context) => const NotebookLLMScreen(),
        '/chat-with-pdf': (context) => const ChatWithPdfScreen(),
        '/ori-chat': (context) => const OriChatScreen(),
        '/plagiarism-check': (context) => const PlagiarismCheckScreen(),
        '/citation-generator': (context) => const CitationGeneratorScreen(),
        '/word-counter': (context) => const WordCounterScreen(),
        '/my-notes': (context) => const MyNotesScreen(),
        '/new-note': (context) => const NewNoteScreen(),
      },
    );
  }
}