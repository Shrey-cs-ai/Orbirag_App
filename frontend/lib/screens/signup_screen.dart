import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../utils/validators.dart';
import '../utils/firebase_auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/social_button.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  final FirebaseAuthService _authService = FirebaseAuthService.instance;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  // ============================================================
  // Strength meter helper
  // ============================================================
  Color _strengthColor(int score) {
    switch (score) {
      case 0:
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      _showMessage('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    final error = await _authService.signUp(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      _showMessage(error);
    } else {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 56),
              child: Center(
                child: SizedBox(
                  width: 420,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          AppConstants.appName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create your account and accelerate your research.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SocialButton(
                              icon: SizedBox(
                                width: 28,
                                height: 28,
                                child: SvgPicture.asset(
                                  'assets/icons/github_logo.svg',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              onPressed: _handleGitHubSignIn,
                            ),
                            const SizedBox(width: 24),
                            SocialButton(
                              icon: SizedBox(
                                width: 28,
                                height: 28,
                                child: SvgPicture.asset(
                                  'assets/icons/google_logo.svg',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              onPressed: _handleGoogleSignIn,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        Row(
                          children: const [
                            Expanded(
                              child: Divider(
                                  color: AppColors.border, thickness: 1),
                            ),
                            Padding(
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
                            Expanded(
                              child: Divider(
                                  color: AppColors.border, thickness: 1),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        CustomTextField(
                          label: 'Full name',
                          hint: 'Alex Johnson',
                          controller: _nameController,
                          validator: Validators.name,
                        ),
                        const SizedBox(height: 18),

                        CustomTextField(
                          label: 'Email address',
                          hint: 'you@example.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.email,
                        ),
                        const SizedBox(height: 18),

                        // ============================================================
                        // PASSWORD FIELD with strong validation
                        // ============================================================
                        CustomTextField(
                          label: 'Password',
                          hint: 'Min 8 chars, 1 uppercase, 1 number, 1 symbol',
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          validator: (value) => Validators.password(value),
                          // 👇 setState on change to update the strength meter
                          onChanged: (value) => setState(() {}),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(
                                  () => _obscurePassword = !_obscurePassword);
                            },
                          ),
                        ),

                        // ============================================================
                        // PASSWORD STRENGTH METER
                        // ============================================================
                        if (_passwordController.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: List.generate(4, (index) {
                                    final score = Validators.passwordStrength(
                                      _passwordController.text,
                                    );
                                    final isActive = index < score;
                                    return Expanded(
                                      child: Container(
                                        height: 6,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 2),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? _strengthColor(score)
                                              : Colors.grey.shade300,
                                          borderRadius:
                                              BorderRadius.circular(3),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Strength: ${Validators.passwordStrengthLabel(
                                    Validators.passwordStrength(
                                        _passwordController.text),
                                  )}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _strengthColor(
                                      Validators.passwordStrength(
                                          _passwordController.text),
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 18),

                        CustomTextField(
                          label: 'Confirm password',
                          hint: '••••••••',
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          validator: (value) => Validators.confirmPassword(
                              value, _passwordController.text),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() => _obscureConfirmPassword =
                                  !_obscureConfirmPassword);
                            },
                          ),
                        ),
                        const SizedBox(height: 24),

                        CustomButton(
                          label: 'Sign up',
                          isLoading: _isLoading,
                          onPressed: _handleSignup,
                        ),
                        const SizedBox(height: 20),

                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Already have an account? ',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: const Text(
                                  'Log in',
                                  style: AppTextStyles.link,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}