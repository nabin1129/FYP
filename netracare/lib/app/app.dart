import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:netracare/core/core.dart';
import 'package:netracare/features/admin/admin.dart';
import 'package:netracare/features/auth/auth.dart';
import 'package:netracare/features/dashboard/dashboard.dart';
import 'package:netracare/features/doctor/doctor.dart';
import 'package:netracare/features/profile/presentation/pages/accessibility_settings_page.dart';
import 'package:netracare/features/tests/tests.dart';

import 'auth_check_page.dart';

class NetraCareApp extends StatelessWidget {
  const NetraCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, _) {
        final settings = themeManager.settings;

        return MaterialApp(
          title: 'NetraCare',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(settings),
          darkTheme: AppTheme.darkTheme(settings),
          themeMode: settings.themeMode,
          themeAnimationDuration: const Duration(milliseconds: 280),
          themeAnimationCurve: Curves.easeInOutCubic,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(settings.textScale),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const AuthCheckPage(),
          routes: {
            '/login': (_) => const LoginPage(),
            '/signup': (_) => const SignupPage(),
            '/forgot-password': (_) => const ForgotPasswordPage(),
            '/dashboard': (_) => const DashboardPage(),
            '/doctor-dashboard': (_) => const DoctorDashboardPage(),
            '/admin/dashboard': (_) => const AdminDashboardPage(),
            '/admin/analytics': (_) => const AdminAnalyticsPage(),
            '/admin/notifications': (_) => const AdminNotificationsPage(),
            '/notifications': (_) => const NotificationsPage(),
            '/profile': (_) => const ProfilePage(),
            '/accessibility-settings': (_) => const AccessibilitySettingsPage(),
            '/visual-acuity': (_) => const VisualAcuityPage(),
            '/eye-tracking': (_) => const EyeTrackingPage(),
            '/pupil-reflex': (_) => const PupilReflexPage(),
            '/colour-vision': (_) => const ColourVisionPage(),
            '/blink-fatigue': (_) => const BlinkFatiguePage(),
            '/results-report': (_) => const ResultsReportPage(),
          },
        );
      },
    );
  }
}
