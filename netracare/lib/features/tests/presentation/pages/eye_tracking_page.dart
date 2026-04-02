import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/features/tests/presentation/pages/eye_tracking_test_page.dart';
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Back button
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: goBack,
              ),
            ),

            // Main Card
            Center(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 380),
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.testIconBackground,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.track_changes,
            size: 56,
            color: AppTheme.testIconColor,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Eye Tracking Test",
          style: TextStyle(
            fontSize: AppTheme.fontTitle,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "This test tracks your eye movements and gaze patterns to assess eye tracking quality and visual performance.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 24),

        // Key Information
        _infoCard(
          icon: Icons.info_outline,
          title: "What to expect",
          description:
              "You'll follow moving objects on the screen with your eyes. The test takes about 2-3 minutes.",
        ),
        const SizedBox(height: 12),
        _infoCard(
          icon: Icons.videocam,
          title: "Camera Required",
          description:
              "This test requires camera access to track your eye movements.",
        ),
        const SizedBox(height: 12),
        _infoCard(
          icon: Icons.lightbulb_outline,
          title: "Good Lighting",
          description:
              "Make sure you're in a well-lit area for accurate tracking.",
        ),

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: proceed,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Continue Setup",
              style: TextStyle(
                fontSize: AppTheme.fontLG,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============ SETUP SCREEN ============
  Widget _setupUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.testIconBackground,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.checklist,
            size: 56,
            color: AppTheme.testIconColor,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Pre-Test Setup",
          style: TextStyle(
            fontSize: AppTheme.fontTitle,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),

        // Setup Checklist
        _checklistItem("Position your device at eye level"),
        const SizedBox(height: 12),
        _checklistItem("Sit 30-40 cm away from the screen"),
        const SizedBox(height: 12),
        _checklistItem("Ensure good ambient lighting"),
        const SizedBox(height: 12),
        _checklistItem(
          "Remove glasses if you don't normally wear them for distance",
        ),
        const SizedBox(height: 12),
        _checklistItem("Keep your head still during the test"),
        const SizedBox(height: 24),

        // Instructions Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Camera permission required. Allow access when prompted.",
                  style: TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: AppTheme.warningDark,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: proceed,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Proceed to Calibration",
              style: TextStyle(
                fontSize: AppTheme.fontLG,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============ CALIBRATION SCREEN ============
  Widget _calibrationUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.settings, size: 56, color: Colors.green),
        ),
        const SizedBox(height: 16),
        const Text(
          "Calibration",
          style: TextStyle(
            fontSize: AppTheme.fontTitle,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Follow the dots on the screen to calibrate the eye tracker.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 24),

        // Calibration Info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.testIconBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.primaryLight.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              _calibrationStep("1", "Focus on the first dot"),
              const SizedBox(height: 12),
              _calibrationStep("2", "Keep your head steady"),
              const SizedBox(height: 12),
              _calibrationStep("3", "Let your eyes follow smoothly"),
              const SizedBox(height: 12),
              _calibrationStep("4", "Calibration takes ~30 seconds"),
            ],
          ),
        ),

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: startTest,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Start Eye Tracking Test",
              style: TextStyle(
                fontSize: AppTheme.fontLG,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============ HELPER WIDGETS ============
  Widget _infoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.testIconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: AppTheme.fontBody,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _checklistItem(String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: AppTheme.fontBody,
              color: AppTheme.textSubtle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _calibrationStep(String number, String description) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            description,
            style: const TextStyle(
              fontSize: AppTheme.fontBody,
              color: AppTheme.textSubtle,
            ),
          ),
        ),
      ],
    );
  }
}
