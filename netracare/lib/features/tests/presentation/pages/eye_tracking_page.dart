import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/features/tests/presentation/pages/eye_tracking_test_page.dart';
import 'package:netracare/features/tests/presentation/widgets/test_widgets.dart';
import 'package:netracare/utils/permission_helper.dart';

class EyeTrackingPage extends StatefulWidget {
  const EyeTrackingPage({super.key});

  @override
  State<EyeTrackingPage> createState() => _EyeTrackingPageState();
}

class _EyeTrackingPageState extends State<EyeTrackingPage> {
  String step = 'intro'; // intro | setup | calibration

  void proceed() {
    if (step == 'intro') {
      setState(() => step = 'setup');
    } else if (step == 'setup') {
      setState(() => step = 'calibration');
    }
  }

  void goBack() {
    if (step != 'intro') {
      setState(() {
        if (step == 'setup') {
          step = 'intro';
        } else if (step == 'calibration') {
          step = 'setup';
        }
      });
    } else {
      Navigator.pop(context);
    }
  }

  void startTest() async {
    final granted = await PermissionHelper.requestCameraPermission(context);
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera permission is required for this test.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EyeTrackingTestPage()),
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
                child: step == 'intro'
                    ? _introUI()
                    : step == 'setup'
                    ? _setupUI()
                    : _calibrationUI(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ INTRO SCREEN ============
  Widget _introUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const TestIconHeader(
          icon: Icons.track_changes,
          iconSize: 56,
          title: 'Eye Tracking Test',
          description:
              'This test tracks your eye movements and gaze patterns to assess eye tracking quality and visual performance.',
        ),
        const SizedBox(height: 24),
        const TestInfoCard(
          icon: Icons.info_outline,
          title: 'What to expect',
          description:
              "You'll follow moving objects on the screen with your eyes. The test takes about 2-3 minutes.",
        ),
        const SizedBox(height: 12),
        const TestInfoCard(
          icon: Icons.videocam,
          title: 'Camera Required',
          description:
              'This test requires camera access to track your eye movements.',
        ),
        const SizedBox(height: 12),
        const TestInfoCard(
          icon: Icons.lightbulb_outline,
          title: 'Good Lighting',
          description:
              'Make sure you\'re in a well-lit area for accurate tracking.',
        ),
        const SizedBox(height: 28),
        TestPrimaryButton(label: 'Continue Setup', onPressed: proceed),
      ],
    );
  }

  // ============ SETUP SCREEN ============
  Widget _setupUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const TestIconHeader(
          icon: Icons.checklist,
          iconSize: 56,
          title: 'Pre-Test Setup',
        ),
        const SizedBox(height: 24),

        const TestChecklistItem(text: 'Position your device at eye level'),
        const SizedBox(height: 12),
        const TestChecklistItem(text: 'Sit 30-40 cm away from the screen'),
        const SizedBox(height: 12),
        const TestChecklistItem(text: 'Ensure good ambient lighting'),
        const SizedBox(height: 12),
        const TestChecklistItem(
          text: "Remove glasses if you don't normally wear them for distance",
        ),
        const SizedBox(height: 12),
        const TestChecklistItem(text: 'Keep your head still during the test'),
        const SizedBox(height: 24),

        const TestWarningBox(
          message: 'Camera permission required. Allow access when prompted.',
        ),
        const SizedBox(height: 28),
        TestPrimaryButton(label: 'Proceed to Calibration', onPressed: proceed),
      ],
    );
  }

  // ============ CALIBRATION SCREEN ============
  Widget _calibrationUI() {
    final colors = context.appColors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TestIconHeader(
          icon: Icons.settings,
          iconSize: 56,
          title: 'Calibration',
          description: 'Follow the dots on the screen to calibrate the eye tracker.',
          iconBgColor: colors.success.withValues(alpha: 0.1),
          iconColor: colors.success,
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.testIconBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colors.primaryLight.withValues(alpha: 0.3),
            ),
          ),
          child: const Column(
            children: [
              TestInstructionStep(number: '1', text: 'Focus on the first dot'),
              SizedBox(height: 12),
              TestInstructionStep(number: '2', text: 'Keep your head steady'),
              SizedBox(height: 12),
              TestInstructionStep(number: '3', text: 'Let your eyes follow smoothly'),
              SizedBox(height: 12),
              TestInstructionStep(number: '4', text: 'Calibration takes ~30 seconds'),
            ],
          ),
        ),
        const SizedBox(height: 28),
        TestPrimaryButton(
          label: 'Start Eye Tracking Test',
          onPressed: startTest,
          color: colors.success,
        ),
      ],
    );
  }
}
