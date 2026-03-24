import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/app_theme.dart';
import '../pages/signup_page.dart';
import '../pages/forgot_password_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/doctor/doctor_dashboard_page.dart';
import '../pages/admin/admin_dashboard_page.dart';
import '../services/api_service.dart';
import '../widgets/auth/animated_input_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;
  String? _errorMessage;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _rememberEmailKey = 'remember_email';
  static const _rememberPasswordKey = 'remember_password';
  static const _rememberMeKey = 'remember_me';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    final remembered = await _storage.read(key: _rememberMeKey);
    if (remembered == 'true') {
      final email = await _storage.read(key: _rememberEmailKey);
      final password = await _storage.read(key: _rememberPasswordKey);
      if (mounted) {
        setState(() {
          _rememberMe = true;
          if (email != null) _emailController.text = email;
          if (password != null) _passwordController.text = password;
        });
      }
    }
  }

  Future<void> _saveOrClearCredentials() async {
    if (_rememberMe) {
      await _storage.write(key: _rememberMeKey, value: 'true');
      await _storage.write(
        key: _rememberEmailKey,
        value: _emailController.text.trim(),
      );
      await _storage.write(
        key: _rememberPasswordKey,
        value: _passwordController.text,
      );
    } else {
      await _storage.delete(key: _rememberMeKey);
      await _storage.delete(key: _rememberEmailKey);
      await _storage.delete(key: _rememberPasswordKey);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLG),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                _buildLogo(),
                const SizedBox(height: AppTheme.spaceLG),
                _buildWelcomeText(),
                const SizedBox(height: AppTheme.spaceXL),
                _buildCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Logo ──────────────────────────────────────────────────────────────

  Widget _buildLogo() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Image.asset(
            'assets/images/netracare_logo.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  // ─── Welcome Text ──────────────────────────────────────────────────────

  Widget _buildWelcomeText() {
    return Column(
      children: [
        Text('Welcome Back', style: AppTheme.heading1),
        const SizedBox(height: AppTheme.spaceXS),
        Text('Sign in to continue to NetraCare', style: AppTheme.bodySecondary),
      ],
    );
  }

  // ─── Main Card ─────────────────────────────────────────────────────────

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLG),
      decoration: AppTheme.elevatedCardDecoration,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) _buildErrorBanner(),

            AnimatedInputField(
              controller: _emailController,
              label: 'Email Address',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Email is required' : null,
            ),
            const SizedBox(height: AppTheme.spaceMD),

            AnimatedInputField(
              controller: _passwordController,
              label: 'Password',
              prefixIcon: Icons.lock_outline,
              obscureText: !_isPasswordVisible,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleLogin(),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Password is required' : null,
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppTheme.textLight,
                ),
                onPressed: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
            const SizedBox(height: AppTheme.spaceSM),

            _buildOptionsRow(),
            const SizedBox(height: AppTheme.spaceLG),

            _buildLoginButton(),
            const SizedBox(height: AppTheme.spaceMD),

            _buildDivider(),
            const SizedBox(height: AppTheme.spaceMD),

            _buildGoogleButton(),
            const SizedBox(height: AppTheme.spaceLG),

            _buildSignUpLink(),
          ],
        ),
      ),
    );
  }

  // ─── Error Banner ──────────────────────────────────────────────────────

  Widget _buildErrorBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceSM),
        decoration: BoxDecoration(
          color: AppTheme.errorBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
            const SizedBox(width: AppTheme.spaceSM),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: AppTheme.error,
                  fontSize: AppTheme.fontSM,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Remember Me + Forgot Password ────────────────────────────────────

  Widget _buildOptionsRow() {
    return Row(
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: _rememberMe,
            onChanged: (v) => setState(() => _rememberMe = v ?? false),
            activeColor: AppTheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spaceXS),
        GestureDetector(
          onTap: () => setState(() => _rememberMe = !_rememberMe),
          child: const Text(
            'Remember me',
            style: TextStyle(
              fontSize: AppTheme.fontSM,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
          ),
          child: const Text(
            'Forgot password?',
            style: TextStyle(
              fontSize: AppTheme.fontSM,
              color: AppTheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Login Button ─────────────────────────────────────────────────────

  Widget _buildLoginButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        style: AppTheme.primaryButton,
        onPressed: _isLoading ? null : _handleLogin,
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text('Sign In', style: AppTheme.button),
      ),
    );
  }

  // ─── Divider ──────────────────────────────────────────────────────────

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppTheme.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMD),
          child: Text(
            'or continue with',
            style: TextStyle(
              fontSize: AppTheme.fontSM,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppTheme.border)),
      ],
    );
  }

  // ─── Google Sign-In ───────────────────────────────────────────────────

  Widget _buildGoogleButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
        ),
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/google_logo.png',
              width: 20,
              height: 20,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.g_mobiledata,
                size: 24,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: AppTheme.spaceSM),
            const Text(
              'Sign in with Google',
              style: TextStyle(
                fontSize: AppTheme.fontBody,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sign Up Link ─────────────────────────────────────────────────────

  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have an account? ",
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SignupPage()),
          ),
          child: const Text(
            'Sign Up',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Login Handler ────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      await _saveOrClearCredentials();

      // ── Admin login (local, no API) ──────────────────────────────
      if (email == 'admin' && password == 'admin333221') {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
          );
        }
        return;
      }

      // ── Doctor login ─────────────────────────────────────────────
      final isDoctor = await ApiService.doctorLogin(email, password);
      if (isDoctor) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DoctorDashboardPage()),
          );
        }
        return;
      }

      // ── Regular user login ───────────────────────────────────────
      await ApiService.login(email, password);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Login failed: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Google Sign-In Handler ───────────────────────────────────────────

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      // Check if Firebase is available
      try {
        final _ = Firebase.app();
      } catch (_) {
        throw Exception(
          'Google Sign-In is not available yet. '
          'Firebase needs to be configured first.',
        );
      }

      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId:
            '735051756678-ubgq2aj18vnd7567ec2cutvg860vt186.apps.googleusercontent.com',
      );
      final account = await googleSignIn.signIn();

      if (account == null) {
        // User cancelled the sign-in
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        throw Exception('Failed to get Google ID token');
      }

      await ApiService.googleSignIn(
        googleToken: idToken,
        email: account.email,
        name: account.displayName ?? account.email.split('@')[0],
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
