import 'package:flutter/material.dart';

import 'package:netracare/config/app_theme.dart';

class AppearanceSettingsCard extends StatelessWidget {
  const AppearanceSettingsCard({
    super.key,
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: colors.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: AppTheme.fontLG,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceXS),
          Text(
            description,
            style: TextStyle(
              fontSize: AppTheme.fontBody,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          child,
        ],
      ),
    );
  }
}
