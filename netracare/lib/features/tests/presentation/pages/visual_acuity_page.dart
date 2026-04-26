import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/features/tests/presentation/pages/visual_acuity_test_page.dart';
import 'package:netracare/features/tests/presentation/pages/visual_acuity_variant.dart';
import 'package:netracare/features/tests/presentation/widgets/test_widgets.dart';

class VisualAcuityPage extends StatefulWidget {
  const VisualAcuityPage({super.key});

  @override
  State<VisualAcuityPage> createState() => _VisualAcuityPageState();
}

class _VisualAcuityPageState extends State<VisualAcuityPage> {
  String step = 'intro'; // intro | setup | preparation
  VisualAcuityVariant selectedVariant = VisualAcuityVariant.snellen;

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
      MaterialPageRoute(
        builder: (context) => VisualAcuityTestPage(variant: selectedVariant),
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
        const TestIconHeader(
          icon: Icons.remove_red_eye,
          iconSize: 56,
          title: 'Visual Acuity Test',
          description:
              'This test measures how clearly you can see letters at different sizes, similar to a clinical eye chart.',
        ),
        const SizedBox(height: 24),
        const TestInfoCard(
          icon: Icons.visibility,
          title: 'What to expect',
          description:
              "You'll identify letters displayed at decreasing sizes. Each correct answer reveals a smaller letter.",
        ),
        const SizedBox(height: 12),
        const TestInfoCard(
          icon: Icons.straighten,
          title: 'Distance Viewing',
          description:
              'Hold your phone at arm\'s length (30-40 cm away) from your eyes.',
        ),
        const SizedBox(height: 12),
        const TestInfoCard(
          icon: Icons.lightbulb_outline,
          title: 'Good Lighting',
          description:
              'Make sure you\'re in a well-lit area for accurate measurements.',
        ),
        const SizedBox(height: 28),
        TestPrimaryButton(label: 'Continue Setup', onPressed: proceed),
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
          icon: Icons.checklist,
          iconSize: 56,
          title: 'Pre-Test Setup',
        ),
        const SizedBox(height: 24),

        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Test type',
            style: TextStyle(
              fontSize: AppTheme.fontBody,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: VisualAcuityVariant.values.map((variant) {
            final isSelected = selectedVariant == variant;
            return ChoiceChip(
              selected: isSelected,
              label: Text(variant.title),
              onSelected: (_) => setState(() => selectedVariant = variant),
              selectedColor: colors.primary.withValues(alpha: 0.14),
              labelStyle: TextStyle(
                color: isSelected ? colors.primary : colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(
                color: isSelected ? colors.primary : colors.border,
              ),
              backgroundColor: colors.surface,
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.primary.withValues(alpha: 0.12)),
          ),
          child: Text(
            selectedVariant.description,
            style: TextStyle(color: colors.textSecondary, height: 1.4),
          ),
        ),
        const SizedBox(height: 20),

        const TestChecklistItem(text: "Find a quiet, well-lit room"),
        const SizedBox(height: 12),
        const TestChecklistItem(text: "Hold the phone at arm's length"),
        const SizedBox(height: 12),
        const TestChecklistItem(text: "Wear distance glasses if applicable"),
        const SizedBox(height: 12),
        const TestChecklistItem(text: "Ensure clear view of the display"),
        const SizedBox(height: 12),
        const TestChecklistItem(text: "Avoid screen glare"),
        const SizedBox(height: 24),

        const TestWarningBox(
          message:
              "You'll be shown 10 prompts. Use the selected test type to answer each one accurately.",
        ),
        const SizedBox(height: 28),
        TestPrimaryButton(label: 'Start Test', onPressed: startTest),
      ],
    );
  }

  // ============ PREPARATION SCREEN ============
  Widget _preparationUI() {
    final colors = context.appColors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TestIconHeader(
          icon: Icons.visibility_outlined,
          iconSize: 56,
          title: 'Ready to Begin',
          description:
              'Follow the instructions carefully and identify each letter as it appears.',
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
          child: Column(
            children: [
              const TestInstructionStep(number: '1', text: 'Read each letter carefully'),
              const SizedBox(height: 12),
              const TestInstructionStep(
                  number: '2', text: 'Select the correct letter from options'),
              const SizedBox(height: 12),
              const TestInstructionStep(
                  number: '3', text: 'Letters get progressively smaller'),
              const SizedBox(height: 12),
              const TestInstructionStep(number: '4', text: 'Test completes after 10 letters'),
            ],
          ),
        ),
        const SizedBox(height: 28),
        TestPrimaryButton(
          label: 'Start Visual Acuity Test',
          onPressed: startTest,
          color: colors.success,
        ),
      ],
    );
  }
}
