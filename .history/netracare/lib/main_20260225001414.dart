import 'package:flutter/material.dart';
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
import 'package:netracare/pages/doctor/doctor_dashboard_page.dart';
import 'package:netracare/pages/admin/admin_dashboard_page.dart';
import 'package:netracare/services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const AuthCheckPage(),

      routes: {
        "/login": (_) => const LoginPage(),
        "/signup": (_) => const SignupPage(),
        "/dashboard": (_) => const DashboardPage(),
        "/doctor-dashboard": (_) => const DoctorDashboardPage(),
        "/admin/dashboard": (_) => const AdminDashboardPage(),
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
      final token = await ApiService.getToken()
          .timeout(const Duration(seconds: 1), onTimeout: () => null);

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
      backgroundColor: const Color(0xFFF2F4F8),
      body: SafeArea(
        child: Center(
          child: _isChecking
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text(
                      'Loading...',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
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
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error: $_error',
                        style: const TextStyle(color: Colors.red),
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
