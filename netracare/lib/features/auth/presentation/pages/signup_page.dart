import 'dart:async';

import 'package:flutter/material.dart';

import 'package:netracare/config/app_theme.dart';
import 'package:netracare/features/dashboard/dashboard.dart';
import 'package:netracare/services/api_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final ageController = TextEditingController();
  String? selectedSex;

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  bool isStrongPassword(String password) {
    final regex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&]).{8,}$',
    );
    return regex.hasMatch(password);
  }

  static bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.com$');
    return emailRegex.hasMatch(email);
  }

  static bool _isValidFullName(String value) {
    final nameRegex = RegExp(r'^[A-Za-z]+(?: [A-Za-z]+){1,3}$');
    return nameRegex.hasMatch(value.trim());
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    final password = passwordController.text;

    if (!isStrongPassword(password)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password must contain:\n'
            '• At least 8 characters\n'
            '• Uppercase letter (A-Z)\n'
            '• Lowercase letter (a-z)\n'
            '• Number (0-9)\n'
            '• Special character (@\$!%*?&)',
          ),
          backgroundColor: AppTheme.error,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await ApiService.signup(
        name: nameController.text.trim(),
        email: emailController.text.trim().toLowerCase(),
        password: password,
        age: ageController.text.isNotEmpty
            ? int.tryParse(ageController.text)
            : null,
        sex: selectedSex,
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
        (route) => false,
      );
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Request timed out. Please check your internet connection.',
          ),
          backgroundColor: AppTheme.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppTheme.standardAppBar(title: 'Create Account'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NetraCare',
                style: AppTheme.heading1.copyWith(
                  fontSize: AppTheme.fontHeading,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSM),
              const Text('Create your account', style: AppTheme.bodySecondary),
              const SizedBox(height: AppTheme.spaceXL),
              _inputField(
                controller: nameController,
                label: 'Full Name',
                icon: Icons.person,
                validator: (v) {
                  final name = v?.trim() ?? '';
                  if (name.isEmpty) return 'Name is required';
                  if (!_isValidFullName(name)) {
                    return 'Enter 2 to 4 words with single spaces only';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _inputField(
                controller: emailController,
                label: 'Email',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final email = v?.trim() ?? '';
                  if (email.isEmpty) return 'Email is required';
                  if (!_isValidEmail(email)) {
                    return 'Please enter a valid .com email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _inputField(
                controller: passwordController,
                label: 'Password',
                icon: Icons.lock,
                obscureText: obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 8) return 'Minimum 8 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _inputField(
                controller: confirmPasswordController,
                label: 'Confirm Password',
                icon: Icons.lock,
                obscureText: obscureConfirmPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      obscureConfirmPassword = !obscureConfirmPassword;
                    });
                  },
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please confirm password';
                  if (v != passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              _inputField(
                controller: ageController,
                label: 'Age (optional)',
                icon: Icons.cake,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppTheme.spaceMD),
              DropdownButtonFormField<String>(
                initialValue: selectedSex,
                decoration: AppTheme.inputDecoration(
                  label: 'Sex (optional)',
                  prefixIcon: Icons.person_outline,
                ),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  setState(() => selectedSex = value);
                },
              ),
              const SizedBox(height: AppTheme.spaceXL),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _signup,
                  style: AppTheme.primaryButton,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('Create Account', style: AppTheme.button),
                ),
              ),
              const SizedBox(height: AppTheme.spaceMD),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Already have an account? Login',
                    style: TextStyle(color: AppTheme.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: AppTheme.inputDecoration(
        label: label,
        prefixIcon: icon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
