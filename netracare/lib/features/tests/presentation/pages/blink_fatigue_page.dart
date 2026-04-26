import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/features/tests/presentation/pages/blink_fatigue_cnn_test_page.dart';
import 'package:netracare/features/tests/presentation/widgets/test_widgets.dart';
import 'package:netracare/services/api_service.dart';
import 'package:netracare/services/blink_fatigue_service.dart';

class BlinkFatiguePage extends StatefulWidget {
  const BlinkFatiguePage({super.key});

  @override
  State<BlinkFatiguePage> createState() => _BlinkFatiguePageState();
}

class _BlinkFatiguePageState extends State<BlinkFatiguePage> {
  String step = 'intro'; // intro | setup
  Map<String, dynamic>? _fatigueConfig;
  bool _loadingConfig = false;

  @override
  void initState() {
    super.initState();
    _loadFatigueConfig();
  }

  Future<void> _loadFatigueConfig() async {
    setState(() => _loadingConfig = true);
    try {
      final config = await BlinkFatigueService.getConfig();
      if (mounted) {
        setState(() => _fatigueConfig = config);
      }
    } catch (_) {
      // Keep the UI usable even if config lookup fails.
    } finally {
      if (mounted) {
        setState(() => _loadingConfig = false);
      }
    }
  }

  void proceed() {
    if (step == 'intro') setState(() => step = 'setup');
  }

  void goBack() {
    if (step != 'intro') {
      setState(() => step = 'intro');
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> startTest() async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        if (mounted) _showSessionExpiredDialog();
        return;
      }
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const BlinkFatigueCNNTestPage(),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showSessionExpiredDialog();
    }
  }

  void _showSessionExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('Session Expired'),
          ],
        ),
        content: const Text(
          'Your session has expired. Please login again to continue.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (route) => false);
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: goBack,
              ),
            ),
            Center(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 380),
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: step == 'intro' ? _introUI() : _setupUI(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ INTRO SCREEN ============
  Widget _introUI() {
    final colors = context.appColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TestIconHeader(
          icon: Icons.visibility_off,
          iconSize: 32,
          title: 'Blink & Fatigue Test',
          description:
              'This test measures your blink rate and detects signs of eye fatigue, which are important indicators of digital eye strain and overall eye health.',
          iconBgColor: colors.testIconBackground,
          iconColor: colors.testIconColor,
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.testIconBackground,
            border: Border.all(
              color: colors.primaryLight.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Before you begin:',
                style: TextStyle(
                  fontSize: AppTheme.fontBody,
                  fontWeight: FontWeight.w600,
                  color: colors.testIconColor,
                ),
              ),
              const SizedBox(height: 12),
              TestCheckItem(
                text: 'Find a comfortable, well-lit environment',
                textColor: colors.textPrimary,
              ),
              const SizedBox(height: 8),
              TestCheckItem(
                text: 'Sit approximately 50-60cm from your device',
                textColor: colors.textPrimary,
              ),
              const SizedBox(height: 8),
              TestCheckItem(
                text: "Blink naturally - don't force or suppress blinking",
                textColor: colors.textPrimary,
              ),
              const SizedBox(height: 8),
              TestCheckItem(
                text: 'The test will take approximately 40 seconds',
                textColor: colors.textPrimary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingConfig)
          Text(
            'Loading test settings...',
            style: TextStyle(
              fontSize: AppTheme.fontSM,
              color: colors.textSecondary,
            ),
          )
        else if (_fatigueConfig != null)
          Text(
            'Backend drowsiness threshold: ${((_fatigueConfig?['drowsy_threshold'] as num?)?.toDouble() ?? 0.6).toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: AppTheme.fontSM,
              color: colors.textSecondary,
            ),
          ),
        const SizedBox(height: 24),
        TestPrimaryButton(label: 'Continue', onPressed: proceed),
      ],
    );
  }

  // ============ SETUP SCREEN ============
  Widget _setupUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const TestIconHeader(
          icon: Icons.videocam,
          iconSize: 32,
          title: 'Camera Setup',
          description: 'Make sure your face is clearly visible and well-lit',
        ),
        const SizedBox(height: 20),
        const TestWarningBox(
          message:
              'Your camera will only be used during this test. No recordings are saved or shared. The AI analyses your blink patterns in real-time.',
          icon: Icons.warning,
        ),
        const SizedBox(height: 24),
        TestPrimaryButton(
          label: 'Enable Camera & Start Test',
          onPressed: startTest,
        ),
      ],
    );
  }
}
