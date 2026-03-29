import 'package:flutter/material.dart';
import 'visual_acuity_test_page.dart';
import '../config/app_theme.dart';

class VisualAcuityPage extends StatefulWidget {
  const VisualAcuityPage({super.key});

  @override
  State<VisualAcuityPage> createState() => _VisualAcuityPageState();
}

class _VisualAcuityPageState extends State<VisualAcuityPage> {
  String step = 'intro'; // intro | setup | preparation

  void proceed() {
    if (step == 'intro') {
      setState(() => step = 'setup');
    } else if (step == 'setup') {
      setState(() => step = 'preparation');
    }
  }

  void goBack() {
    if (step != 'intro') {
      setState(() {
        if (step == 'setup') {
          step = 'intro';
        } else if (step == 'preparation') {
          step = 'setup';
        }
      });
    } else {
      Navigator.pop(context);
    }
  }

  void startTest() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VisualAcuityTestPage()),
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
                    : _preparationUI(),
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
            Icons.remove_red_eye,
            size: 56,
            color: AppTheme.testIconColor,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Visual Acuity Test",
          style: TextStyle(fontSize: AppTheme.fontTitle, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          "This test measures how clearly you can see letters at different sizes, similar to a clinical eye chart.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 24),

        // Key Information
        _infoCard(
          icon: Icons.visibility,
          title: "What to expect",
          description:
              "You'll identify letters displayed at decreasing sizes. Each correct answer reveals a smaller letter.",
        ),
        const SizedBox(height: 12),
        _infoCard(
          icon: Icons.straighten,
          title: "Distance Viewing",
          description:
              "Hold your phone at arm's length (30-40 cm away) from your eyes.",
        ),
        const SizedBox(height: 12),
        _infoCard(
          icon: Icons.lightbulb_outline,
          title: "Good Lighting",
          description:
              "Make sure you're in a well-lit area for accurate measurements.",
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
          style: TextStyle(fontSize: AppTheme.fontTitle, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),

        // Setup Checklist
        _checklistItem("Find a quiet, well-lit room"),
        const SizedBox(height: 12),
        _checklistItem("Hold the phone at arm's length"),
        const SizedBox(height: 12),
        _checklistItem("Wear distance glasses if applicable"),
        const SizedBox(height: 12),
        _checklistItem("Ensure clear view of the display"),
        const SizedBox(height: 12),
        _checklistItem("Avoid screen glare"),
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
                  "You'll be shown 10 letters. Identify each one for accurate results.",
                  style: TextStyle(fontSize: AppTheme.fontSM, color: AppTheme.warningDark),
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
              "Proceed to Test",
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

  // ============ PREPARATION SCREEN ============
  Widget _preparationUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.visibility_outlined,
            size: 56,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Ready to Begin",
          style: TextStyle(fontSize: AppTheme.fontTitle, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          "Follow the instructions carefully and identify each letter as it appears.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 24),

        // Test Instructions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.testIconBackground,
            border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              _instructionStep("1", "Read each letter carefully"),
              const SizedBox(height: 12),
              _instructionStep("2", "Select the correct letter from options"),
              const SizedBox(height: 12),
              _instructionStep("3", "Letters get progressively smaller"),
              const SizedBox(height: 12),
              _instructionStep("4", "Test completes after 10 letters"),
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
              "Start Visual Acuity Test",
              style: TextStyle(fontSize: AppTheme.fontLG, fontWeight: FontWeight.w600),
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
            style: const TextStyle(fontSize: AppTheme.fontBody, color: AppTheme.textSubtle),
          ),
        ),
      ],
    );
  }

  Widget _instructionStep(String number, String description) {
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
            style: const TextStyle(fontSize: AppTheme.fontBody, color: AppTheme.textSubtle),
          ),
        ),
      ],
    );
  }
}
