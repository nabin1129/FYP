import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/features/tests/presentation/pages/colour_vision_test_page.dart';
import 'package:netracare/features/tests/presentation/widgets/test_widgets.dart';

class ColourVisionPage extends StatefulWidget {
  const ColourVisionPage({super.key});

  @override
  State<ColourVisionPage> createState() => _ColourVisionPageState();
}

class _ColourVisionPageState extends State<ColourVisionPage> {
  String step = 'intro'; // intro | setup

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

  void startTest() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ColourVisionTestPage()),
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
        const TestIconHeader(
          icon: Icons.palette,
          iconSize: 32,
          title: 'Colour Vision Test',
          description:
              'This test uses Ishihara plates to detect colour vision deficiencies, particularly red-green colour blindness.',
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.testIconBackground,
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
                text: 'Ensure you are in a well-lit room with natural lighting if possible',
                textColor: colors.textPrimary,
              ),
              const SizedBox(height: 8),
              TestCheckItem(
                text: 'Adjust your screen brightness to a comfortable level',
                textColor: colors.textPrimary,
              ),
              const SizedBox(height: 8),
              TestCheckItem(
                text: "View the screen from approximately 75cm (arm's length)",
                textColor: colors.textPrimary,
              ),
              const SizedBox(height: 8),
              TestCheckItem(
                text: 'This is a screening test only. Consult an eye specialist for diagnosis',
                icon: Icons.warning,
                iconColor: colors.warning,
                textColor: colors.textPrimary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TestPrimaryButton(label: 'Continue', onPressed: proceed),
      ],
    );
  }

  // ============ SETUP SCREEN ============
  Widget _setupUI() {
    final colors = context.appColors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const TestIconHeader(
          icon: Icons.info,
          iconSize: 32,
          title: 'Test Instructions',
          description:
              'You will see a series of Ishihara colour plates. For each plate, select the number you see as quickly as possible.',
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.testIconBackground,
            border: Border.all(
              color: colors.primaryLight.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb, color: colors.testIconColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Make sure your screen is properly calibrated for accurate results.',
                  style: TextStyle(
                    fontSize: AppTheme.fontBody,
                    color: colors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TestPrimaryButton(
          label: 'Start Test',
          onPressed: startTest,
          color: colors.success,
        ),
      ],
    );
  }
}
