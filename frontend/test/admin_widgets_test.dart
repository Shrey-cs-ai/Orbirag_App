import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbirag/utils/app_colors.dart';
import 'package:orbirag/widgets/admin/license_usage_card.dart';
import 'package:orbirag/widgets/admin/stat_card.dart';
import 'package:orbirag/widgets/admin/activity_tile.dart';
import 'package:orbirag/widgets/admin/trend_card.dart';

void main() {
  group('LicenseUsageCard Tests', () {
    testWidgets('renders numbers, labels and progress bar with success color (<85%)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LicenseUsageCard(used: 50, limit: 100),
          ),
        ),
      );

      expect(find.text('Licenses used'), findsOneWidget);
      expect(find.text('50% utilized'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.text(' / 100'), findsOneWidget);

      final progressFinder = find.byType(LinearProgressIndicator);
      expect(progressFinder, findsOneWidget);
      final progress = tester.widget<LinearProgressIndicator>(progressFinder);
      expect(progress.value, 0.5);
      final colorAnim = progress.valueColor as AlwaysStoppedAnimation<Color>;
      expect(colorAnim.value, AppColors.success);
    });

    testWidgets('progress bar uses warning color for 85-94%', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LicenseUsageCard(used: 90, limit: 100),
          ),
        ),
      );

      expect(find.text('90% utilized'), findsOneWidget);
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      final colorAnim = progress.valueColor as AlwaysStoppedAnimation<Color>;
      expect(colorAnim.value, AppColors.warning);
    });

    testWidgets('progress bar uses error color for >=95%', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LicenseUsageCard(used: 96, limit: 100),
          ),
        ),
      );

      expect(find.text('96% utilized'), findsOneWidget);
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      final colorAnim = progress.valueColor as AlwaysStoppedAnimation<Color>;
      expect(colorAnim.value, AppColors.error);
    });
  });

  group('StatCard Tests', () {
    testWidgets('renders title, value, helper text, and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCard(
              title: 'Active Students',
              value: '16',
              helperText: 'Used Orbirag in the last 30 days',
              icon: Icons.people_outline,
              iconColor: AppColors.primary,
            ),
          ),
        ),
      );

      expect(find.text('Active Students'), findsOneWidget);
      expect(find.text('16'), findsOneWidget);
      expect(find.text('Used Orbirag in the last 30 days'), findsOneWidget);
      expect(find.byIcon(Icons.people_outline), findsOneWidget);
    });

    testWidgets('renders renewal card with badge', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCard(
              title: 'Renewal',
              value: 'Campus Pro',
              helperText: 'Renews: 2027-10-28',
              badgeText: '365 days left',
              badgeColor: AppColors.success,
              icon: Icons.calendar_today_outlined,
            ),
          ),
        ),
      );

      expect(find.text('Renewal'), findsOneWidget);
      expect(find.text('Campus Pro'), findsOneWidget);
      expect(find.text('Renews: 2027-10-28'), findsOneWidget);
      expect(find.text('365 days left'), findsOneWidget);
    });
  });

  group('ActivityTile Tests', () {
    testWidgets('renders icon, title, subtitle, and time', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ActivityTile(
              icon: Icons.login,
              iconColor: AppColors.primary,
              title: 'Admin Login',
              subtitle: 'From 127.0.0.1',
              time: '5m ago',
            ),
          ),
        ),
      );

      expect(find.text('Admin Login'), findsOneWidget);
      expect(find.text('From 127.0.0.1'), findsOneWidget);
      expect(find.text('5m ago'), findsOneWidget);
      expect(find.byIcon(Icons.login), findsOneWidget);
    });
  });

  group('TrendCard Tests', () {
    testWidgets('renders weekly active count and trend line chart', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TrendCard(
              activeThisWeek: 12,
              totalActive: 16,
            ),
          ),
        ),
      );

      expect(find.text('Weekly active students'), findsOneWidget);
      expect(find.text('12 active this week'), findsOneWidget);
      expect(find.text('Week 1'), findsOneWidget);
      expect(find.text('Week 2'), findsOneWidget);
      expect(find.text('Week 3'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}

