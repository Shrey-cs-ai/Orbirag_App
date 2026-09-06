import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../utils/firebase_auth_service.dart';
import '../widgets/app_scaffold.dart';

/// Placeholder landing screen shown after a successful login/signup.
/// Replace with the real dashboard UI.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuthService.instance.currentUser;
    return AppScaffold(
      title: 'Orbirag',
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: AppColors.textPrimary),
          onPressed: () async {
            await FirebaseAuthService.instance.signOut();
            if (context.mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppConstants.routeLogin,
                (route) => false,
              );
            }
          },
        ),
      ],
      body: Center(
        child: Text(
          'Signed in as ${user?.email ?? 'Unknown user'}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
