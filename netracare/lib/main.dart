import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/pages/login_page.dart';
import 'package:netracare/pages/signup_page.dart';
import 'package:netracare/pages/dashboard_page.dart';
import 'package:netracare/pages/profile_page.dart';
import 'package:netracare/pages/eye_tracking_page.dart';
import 'package:netracare/pages/visual_acuity_page.dart';
import 'package:netracare/pages/pupil_reflex_page.dart';
import 'package:netracare/pages/colour_vision_page.dart';
import 'package:netracare/pages/blink_fatigue_page.dart';
import 'package:netracare/pages/results_report_page.dart';
import 'package:netracare/pages/forgot_password_page.dart';
import 'package:netracare/pages/doctor/doctor_dashboard_page.dart';
import 'package:netracare/pages/admin/admin_dashboard_page.dart';
import 'package:netracare/pages/admin/admin_analytics_page.dart';
import 'package:netracare/pages/admin/admin_notifications_page.dart';
import 'package:netracare/pages/notifications_page.dart';
import 'package:netracare/services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase not configured yet — Google Sign-In will be unavailable
    debugPrint('Firebase not initialized. Google Sign-In disabled.');
  }
  runApp(const NetraCareApp());
}

class NetraCareApp extends StatelessWidget {
  const NetraCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "NetraCare",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primary),
        scaffoldBackgroundColor: AppTheme.background,
      ),
      home: const AuthCheckPage(),

      routes: {
        "/login": (_) => const LoginPage(),
        "/signup": (_) => const SignupPage(),
        "/forgot-password": (_) => const ForgotPasswordPage(),
        "/dashboard": (_) => const DashboardPage(),
        "/doctor-dashboard": (_) => const DoctorDashboardPage(),
        "/admin/dashboard": (_) => const AdminDashboardPage(),
        "/admin/analytics": (_) => const AdminAnalyticsPage(),
        "/admin/notifications": (_) => const AdminNotificationsPage(),
        "/notifications": (_) => const NotificationsPage(),
        "/profile": (_) => const ProfilePage(),
        "/visual-acuity": (_) => const VisualAcuityPage(),
        "/eye-tracking": (_) => const EyeTrackingPage(),
        "/pupil-reflex": (_) => const PupilReflexPage(),
        "/colour-vision": (_) => const ColourVisionPage(),
        "/blink-fatigue": (_) => const BlinkFatiguePage(),
        "/results-report": (_) => const ResultsReportPage(),
      },
    );
  }
}

class AuthCheckPage extends StatefulWidget {
  const AuthCheckPage({super.key});

  @override
  State<AuthCheckPage> createState() => _AuthCheckPageState();
}

class _AuthCheckPageState extends State<AuthCheckPage> {
  bool _isChecking = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Add a small delay before checking auth to ensure UI is rendered first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  Future<void> _checkAuth() async {
    try {
      final token = await ApiService.getToken().timeout(
        const Duration(seconds: 1),
        onTimeout: () => null,
      );

      if (mounted) {
        setState(() => _isChecking = false);

        if (token != null && token.isNotEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardPage()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _error = e.toString();
        });
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: _isChecking
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: AppTheme.primary),
                    const SizedBox(height: 20),
                    Text(
                      'Loading...',
                      style: TextStyle(
                        fontSize: AppTheme.fontLG,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                )
              : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppTheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error: $_error',
                        style: const TextStyle(color: AppTheme.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                          );
                        },
                        child: const Text('Go to Login'),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
