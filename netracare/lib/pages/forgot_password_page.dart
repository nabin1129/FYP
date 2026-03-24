import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/auth/animated_input_field.dart';

/// Two-step forgot password flow:
///   Step 1 — Enter email → backend sends 6-digit OTP via Gmail
///   Step 2 — Enter OTP + new password → backend resets password
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isStep2 = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppTheme.standardAppBar(title: 'Reset Password'),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spaceLG),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(AppTheme.spaceLG),
            decoration: AppTheme.elevatedCardDecoration,
            child: Form(
              key: _formKey,
              child: _isStep2 ? _buildStep2() : _buildStep1(),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Step 1: Request OTP ──────────────────────────────────────────────

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_reset, size: 48, color: AppTheme.primary),
        const SizedBox(height: AppTheme.spaceMD),
        Text(
          'Forgot Password?',
          style: AppTheme.heading2,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.spaceSM),
        Text(
          'Enter your email address and we\'ll send you a verification code to reset your password.',
          style: AppTheme.bodySecondary,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.spaceLG),

        if (_error != null) _buildMessage(_error!, isError: true),
        if (_success != null) _buildMessage(_success!, isError: false),

        AnimatedInputField(
          controller: _emailController,
          label: 'Email Address',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _requestOtp(),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Email is required';
            if (!v.contains('@')) return 'Enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: AppTheme.spaceLG),

        SizedBox(
          height: 50,
          child: ElevatedButton(
            style: AppTheme.primaryButton,
            onPressed: _isLoading ? null : _requestOtp,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Send Verification Code', style: AppTheme.button),
          ),
        ),
        const SizedBox(height: AppTheme.spaceMD),

        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Back to Login',
            style: TextStyle(color: AppTheme.primary),
          ),
        ),
      ],
    );
  }

  // ─── Step 2: Enter OTP + New Password ─────────────────────────────────

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.verified_user_outlined,
          size: 48,
          color: AppTheme.success,
        ),
        const SizedBox(height: AppTheme.spaceMD),
        Text(
          'Verify & Reset',
          style: AppTheme.heading2,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.spaceSM),
        Text(
          'Enter the 6-digit code sent to ${_emailController.text.trim()} and your new password.',
          style: AppTheme.bodySecondary,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.spaceLG),

        if (_error != null) _buildMessage(_error!, isError: true),
        if (_success != null) _buildMessage(_success!, isError: false),

        AnimatedInputField(
          controller: _otpController,
          label: 'Verification Code',
          prefixIcon: Icons.pin_outlined,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Code is required';
            if (v.length != 6) return 'Enter the 6-digit code';
            return null;
          },
        ),
        const SizedBox(height: AppTheme.spaceMD),

        AnimatedInputField(
          controller: _newPasswordController,
          label: 'New Password',
          prefixIcon: Icons.lock_outline,
          obscureText: _obscureNew,
          textInputAction: TextInputAction.next,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureNew
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppTheme.textLight,
            ),
            onPressed: () => setState(() => _obscureNew = !_obscureNew),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Password is required';
            if (v.length < 8) return 'Min 8 characters';
            final regex = RegExp(
              r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])',
            );
            if (!regex.hasMatch(v)) {
              return 'Needs uppercase, lowercase, number & special char';
            }
            return null;
          },
        ),
        const SizedBox(height: AppTheme.spaceMD),

        AnimatedInputField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          prefixIcon: Icons.lock_outline,
          obscureText: _obscureConfirm,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _resetPassword(),
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirm
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppTheme.textLight,
            ),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
          validator: (v) {
            if (v != _newPasswordController.text)
              return 'Passwords do not match';
            return null;
          },
        ),
        const SizedBox(height: AppTheme.spaceLG),

        SizedBox(
          height: 50,
          child: ElevatedButton(
            style: AppTheme.primaryButton,
            onPressed: _isLoading ? null : _resetPassword,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Reset Password', style: AppTheme.button),
          ),
        ),
        const SizedBox(height: AppTheme.spaceSM),

        TextButton(
          onPressed: () => setState(() {
            _isStep2 = false;
            _error = null;
            _success = null;
          }),
          child: const Text(
            'Resend code / change email',
            style: TextStyle(color: AppTheme.primary),
          ),
        ),
      ],
    );
  }

  // ─── Status Message ───────────────────────────────────────────────────

  Widget _buildMessage(String msg, {required bool isError}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceSM),
        decoration: BoxDecoration(
          color: isError ? AppTheme.errorBg : AppTheme.successBgLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(
            color: isError
                ? AppTheme.error.withValues(alpha: 0.3)
                : AppTheme.success.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? AppTheme.error : AppTheme.success,
              size: 20,
            ),
            const SizedBox(width: AppTheme.spaceSM),
            Expanded(
              child: Text(
                msg,
                style: TextStyle(
                  color: isError ? AppTheme.error : AppTheme.successDark,
                  fontSize: AppTheme.fontSM,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Request OTP ──────────────────────────────────────────────────────

  Future<void> _requestOtp() async {
    setState(() {
      _error = null;
      _success = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ApiService.forgotPassword(_emailController.text.trim());
      if (mounted) {
        setState(() {
          _isStep2 = true;
          _success = 'Verification code sent! Check your email.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ─── Reset Password ──────────────────────────────────────────────────

  Future<void> _resetPassword() async {
    setState(() {
      _error = null;
      _success = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ApiService.resetPassword(
        email: _emailController.text.trim(),
        otp: _otpController.text.trim(),
        newPassword: _newPasswordController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successful! Please sign in.'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }
}
