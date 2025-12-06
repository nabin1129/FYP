import 'package:flutter/material.dart';
import 'package:netracare/pages/login_page.dart';
import 'package:netracare/pages/signup_page.dart';
import 'package:netracare/pages/dashboard_page.dart';
import 'package:netracare/pages/profile_page.dart';

void main() {
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
      home: const LoginPage(),

      routes: {
        "/login": (_) => const LoginPage(),
        "/signup": (_) => const SignupPage(),
        "/dashboard": (_) => const DashboardPage(),
        "/profile": (_) => const ProfilePage(),
      },
    );
  }
}
