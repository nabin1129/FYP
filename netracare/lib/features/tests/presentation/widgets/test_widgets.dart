import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';

/// Circular icon + title + optional description header used on every test intro screen.
class TestIconHeader extends StatelessWidget {
  const TestIconHeader({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.iconBgColor,
    this.iconColor,
    this.iconSize = 32,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Color? iconBgColor;
  final Color? iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: iconBgColor ?? colors.testIconBackground,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: iconSize, color: iconColor ?? colors.testIconColor),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: TextStyle(
            fontSize: AppTheme.fontTitle,
            fontWeight: FontWeight.bold,
            color: colors.textDark,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 12),
          Text(
            description!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTheme.fontBody,
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

/// Bordered info card with icon, bold title and body description.
/// Used in visual acuity and eye tracking intro screens.
class TestInfoCard extends StatelessWidget {
  const TestInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.testIconColor, size: 24),
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
                  style: TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Square-box style checklist row (visual acuity / eye tracking setup).
class TestChecklistItem extends StatelessWidget {
  const TestChecklistItem({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: colors.success,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(Icons.check, color: colors.surface, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: AppTheme.fontBody,
              color: colors.textSubtle,
            ),
          ),
        ),
      ],
    );
  }
}

/// Circle-icon style check row (blink fatigue / pupil reflex / colour vision).
class TestCheckItem extends StatelessWidget {
  const TestCheckItem({
    super.key,
    required this.text,
    this.icon = Icons.check_circle,
    this.iconColor,
    this.textColor,
  });

  final String text;
  final IconData icon;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor ?? colors.success),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: AppTheme.fontBody,
              color: textColor ?? colors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// Amber/warning info box used in setup screens.
class TestWarningBox extends StatelessWidget {
  const TestWarningBox({
    super.key,
    required this.message,
    this.icon = Icons.warning_amber_rounded,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.warningBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.warningBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: AppTheme.fontBody,
                color: colors.warningDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Numbered instruction step row (visual acuity preparation / eye tracking calibration).
class TestInstructionStep extends StatelessWidget {
  const TestInstructionStep({super.key, required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(color: colors.surface, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: AppTheme.fontBody,
              color: colors.textSubtle,
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-width primary action button themed to colors.primary.
class TestPrimaryButton extends StatelessWidget {
  const TestPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          backgroundColor: color ?? colors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: AppTheme.fontLG,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Metric card for test result screens (icon + label + value on a surface card).
class TestMetricCard extends StatelessWidget {
  const TestMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTheme.fontBody,
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTheme.fontHeading,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
