import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/features/tests/presentation/pages/pupil_reflex_test_page.dart';
import 'package:netracare/features/tests/presentation/widgets/test_widgets.dart';

class PupilReflexPage extends StatefulWidget {
  const PupilReflexPage({super.key});

  @override
  State<PupilReflexPage> createState() => _PupilReflexPageState();
}

class _PupilReflexPageState extends State<PupilReflexPage> {
  String step = 'intro'; // intro | setup | warning

  void proceed() {
    if (step == 'intro') {
      setState(() => step = 'setup');
    } else if (step == 'setup') {
      setState(() => step = 'warning');
    }
  }

  void goBack() {
    if (step != 'intro') {
      setState(() {
        if (step == 'setup') {
          step = 'intro';
        } else if (step == 'warning') {
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
      MaterialPageRoute(builder: (context) => const PupilReflexTestPage()),
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
                    : _warningUI(),
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
          icon: Icons.flash_on,
          iconSize: 32,
          title: 'Pupil & Eye Movement Tests',
          description:
              'Comprehensive test to evaluate pupil reflexes and eye movements in one session.',
        ),
        const SizedBox(height: 24),
        _testOptionCard(
          icon: Icons.flash_on,
          title: 'Pupil Reflex & Nystagmus Test',
          description: 'Comprehensive test for pupil response and eye movements',
          onTap: proceed,
        ),
      ],
    );
  }

  Widget _testOptionCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    bool isNew = false,
  }) {
    final colors = context.appColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.testIconBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: colors.testIconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppTheme.fontLG,
                            fontWeight: FontWeight.bold,
                            color: colors.textDark,
                          ),
                        ),
                      ),
                      if (isNew) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.success,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: AppTheme.fontXS,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: AppTheme.fontSM,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
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
          description:
              "We'll need access to your camera to observe your pupil reactions during the test.",
        ),
        const SizedBox(height: 20),
        const TestWarningBox(
          message:
              'Your camera will only be used during this test. No recordings are saved or shared.',
          icon: Icons.info_rounded,
        ),
        const SizedBox(height: 24),
        TestPrimaryButton(label: 'Continue', onPressed: proceed),
      ],
    );
  }

  // ============ WARNING SCREEN ============
  Widget _warningUI() {
    final colors = context.appColors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TestIconHeader(
          icon: Icons.warning_rounded,
          iconSize: 32,
          title: 'Before You Begin',
          iconBgColor: colors.warningBg,
          iconColor: colors.warning,
        ),
        const SizedBox(height: 20),

        TestCheckItem(
          text: 'Find a dimly lit, quiet room',
          textColor: colors.textSecondary,
        ),
        const SizedBox(height: 12),
        TestCheckItem(
          text: "Position yourself approximately 1 arm's length from your device",
          textColor: colors.textSecondary,
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.errorBg,
            border: Border.all(color: colors.error.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_rounded, color: colors.error, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'This test will use brief flashes of light. Do not take this test if you have photosensitive epilepsy.',
                  style: TextStyle(
                    fontSize: AppTheme.fontBody,
                    color: colors.error,
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
