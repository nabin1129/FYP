import 'package:flutter/material.dart';
import 'package:netracare/pages/login_page.dart';
import 'package:netracare/pages/signup_page.dart';
import 'package:netracare/pages/dashboard_page.dart';
import 'package:netracare/pages/profile_page.dart';
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
        "/profile": (_) => const ProfilePage(),
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
    print('AuthCheckPage: Starting auth check...');
    try {
      // Use a timeout wrapper to prevent hanging
      final token = await Future.any([
        ApiService.getToken(),
        Future.delayed(const Duration(seconds: 3), () => null as String?),
      ]);
      
      print('AuthCheckPage: Token check completed. Token: ${token != null ? "exists" : "null"}');
      
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
        print('AuthCheckPage: State updated, navigating...');
        
        // Add a small delay to ensure UI is ready
        await Future.delayed(const Duration(milliseconds: 300));
        
        if (mounted) {
          if (token != null && token.isNotEmpty) {
            print('AuthCheckPage: Navigating to Dashboard');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const DashboardPage()),
            );
          } else {
            print('AuthCheckPage: Navigating to Login');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          }
        }
      }
    } catch (e, stackTrace) {
      print('AuthCheckPage: Error occurred: $e');
      print('AuthCheckPage: Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isChecking = false;
          _error = e.toString();
        });
        // If there's an error, go to login page after a delay
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) {
          print('AuthCheckPage: Navigating to Login due to error');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('AuthCheckPage: Building widget. _isChecking: $_isChecking, _error: $_error');
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
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
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
                                MaterialPageRoute(builder: (_) => const LoginPage()),
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
