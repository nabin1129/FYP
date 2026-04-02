import 'package:flutter/material.dart';

import 'package:netracare/core/core.dart';
import 'package:netracare/features/admin/admin.dart';
import 'package:netracare/features/auth/auth.dart';
import 'package:netracare/features/dashboard/dashboard.dart';
import 'package:netracare/features/doctor/doctor.dart';
import 'package:netracare/features/tests/tests.dart';

import 'auth_check_page.dart';

class NetraCareApp extends StatelessWidget {
  const NetraCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NetraCare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primary),
        scaffoldBackgroundColor: AppTheme.background,
      ),
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
        '/visual-acuity': (_) => const VisualAcuityPage(),
        '/eye-tracking': (_) => const EyeTrackingPage(),
        '/pupil-reflex': (_) => const PupilReflexPage(),
        '/colour-vision': (_) => const ColourVisionPage(),
        '/blink-fatigue': (_) => const BlinkFatiguePage(),
        '/results-report': (_) => const ResultsReportPage(),
      },
    );
  }
}
