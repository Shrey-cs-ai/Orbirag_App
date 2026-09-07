import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../utils/validators.dart';
import '../utils/firebase_auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/social_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  final FirebaseAuthService _authService = FirebaseAuthService.instance;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ==================== HANDLERS ====================

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final error = await _authService.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      _showMessage(error);
    } else {
      // Save remember me preference if needed
      if (_rememberMe) {
        // You can save this using SharedPreferences
      }
      Navigator.of(context).pushReplacementNamed(AppConstants.routeHome);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    final error = await _authService.signInWithGoogle();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      _showMessage(error);
    } else {
      Navigator.of(context).pushReplacementNamed(AppConstants.routeHome);
    }
  }

  Future<void> _handleGitHubSignIn() async {
    setState(() => _isLoading = true);

    final error = await _authService.signInWithGitHub();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      _showMessage(error);
    } else {
      Navigator.of(context).pushReplacementNamed(AppConstants.routeHome);
    }
  }

  Future<void> _handleLinkedInSignIn() async {
    setState(() => _isLoading = true);

    final error = await _authService.signInWithLinkedIn();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      _showMessage(error);
    } else {
      Navigator.of(context).pushReplacementNamed(AppConstants.routeHome);
    }
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Name
                const Text(
                  AppConstants.appName,
                  style: AppTextStyles.heading,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Welcome back. Please login to your account.',
                  style: AppTextStyles.subheading,
                ),
                const SizedBox(height: 28),

                // Social Login Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // GitHub
                    SocialButton(
                      icon: Icon(
                        Icons.code,
                        color: AppColors.github,
                        size: 28,
                      ),
                      onPressed: _handleGitHubSignIn,
                    ),
                    // LinkedIn
                    SocialButton(
                      icon: Icon(
                        Icons.business_center,
                        color: AppColors.linkedin,
                        size: 28,
                      ),
                      onPressed: _handleLinkedInSignIn,
                    ),
                    // Google
                    SocialButton(
                      icon: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        child: const Text(
                          'G',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            color: AppColors.google,
                          ),
                        ),
                      ),
                      onPressed: _handleGoogleSignIn,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // OR Divider
                Row(
                  children: [
                    const Expanded(
                      child: Divider(color: AppColors.border, thickness: 1),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(color: AppColors.border, thickness: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Email Field
                CustomTextField(
                  label: 'Email address',
                  hint: 'you@example.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
                const SizedBox(height: 18),

                // Password Field
                CustomTextField(
                  label: 'Password',
                  hint: '••••••••',
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  validator: (value) => Validators.password(value, minLength: 6),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Remember Me & Forgot Password
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: _rememberMe,
                            activeColor: AppColors.primary,
                            onChanged: (value) {
                              setState(() => _rememberMe = value ?? false);
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Remember me',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context)
                            .pushNamed(AppConstants.routeForgotPassword);
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Forgot password?',
                        style: AppTextStyles.link,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Login Button
                CustomButton(
                  label: 'Log in',
                  isLoading: _isLoading,
                  onPressed: _handleLogin,
                ),
                const SizedBox(height: 20),

                // Sign Up Navigation
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context)
                              .pushNamed(AppConstants.routeSignup);
                        },
                        child: const Text(
                          'Sign up',
                          style: AppTextStyles.link,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Security Message
                const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Your data is secure',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}