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
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final error = await FirebaseAuthService.instance.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      _showMessage(error);
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppConstants.routeHome,
        (route) => false,
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final error = await FirebaseAuthService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error != null) {
      _showMessage(error);
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppConstants.routeHome,
        (route) => false,
      );
    }
  }

  Future<void> _handleGitHubSignIn() async {
    setState(() => _isLoading = true);
    final error = await FirebaseAuthService.instance.signInWithGitHub();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error != null) {
      _showMessage(error);
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppConstants.routeHome,
        (route) => false,
      );
    }
  }

  Future<void> _handleLinkedInSignIn() async {
    setState(() => _isLoading = true);
    final error = await FirebaseAuthService.instance.signInWithLinkedIn();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error != null) {
      _showMessage(error);
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppConstants.routeHome,
        (route) => false,
      );
    }
  }

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
                const Text(AppConstants.appName, style: AppTextStyles.heading),
                const SizedBox(height: 4),
                const Text(
                  'Welcome back. Please login to your account.',
                  style: AppTextStyles.subheading,
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SocialButton(
                      icon: const Icon(Icons.code, color: Colors.black87),
                      onPressed: _handleGitHubSignIn,
                    ),
                    SocialButton(
                      icon: const Icon(Icons.business, color: Color(0xFF0A66C2)),
                      onPressed: _handleLinkedInSignIn,
                    ),
                    SocialButton(
                      icon: const Text('G',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: Color(0xFFEA4335))),
                      onPressed: _handleGoogleSignIn,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: const [
                    Expanded(child: Divider(color: AppColors.border)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ),
                    Expanded(child: Divider(color: AppColors.border)),
                  ],
                ),
                const SizedBox(height: 24),
                CustomTextField(
                  label: 'Email address',
                  hint: 'you@example.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  label: 'Password',
                  hint: '••••••••',
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  validator: (value) => Validators.password(value, minLength: 6),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 12),
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
                            onChanged: (value) => setState(() => _rememberMe = value ?? false),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('Remember me', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushNamed(AppConstants.routeForgotPassword),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: const Text('Forgot password?', style: AppTextStyles.link),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                CustomButton(
                  label: 'Log in',
                  isLoading: _isLoading,
                  onPressed: _handleLogin,
                ),
                const SizedBox(height: 20),
                Center(
                  child: Wrap(
                    children: [
                      const Text("Don't have an account? ", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pushNamed(AppConstants.routeSignup),
                        child: const Text('Sign up', style: AppTextStyles.link),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.lock_outline, size: 14, color: AppColors.textSecondary),
                      SizedBox(width: 6),
                      Text('Your data is secure', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}