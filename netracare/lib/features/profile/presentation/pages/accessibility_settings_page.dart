import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:netracare/config/app_theme.dart';
import 'package:netracare/features/profile/presentation/widgets/appearance_settings_card.dart';

class AccessibilitySettingsPage extends StatelessWidget {
  const AccessibilitySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final themeManager = context.watch<ThemeManager>();
    final settings = themeManager.settings;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Accessibility'),
        backgroundColor: colors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        children: [
          AppearanceSettingsCard(
            title: 'Display mode',
            description:
                'Use system appearance or switch the full app between light and dark mode.',
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto),
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode),
                  label: Text('Dark'),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (selection) {
                themeManager.updateThemeMode(selection.first);
              },
            ),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          AppearanceSettingsCard(
            title: 'Color accessibility',
            description:
                'Swap to a color-blind-safe palette with stronger contrast across patient, doctor, and admin pages.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...AccessibilityMode.values.map(
                  (mode) => Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spaceSM),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      onTap: () => themeManager.updateAccessibilityMode(mode),
                      child: Container(
                        padding: const EdgeInsets.all(AppTheme.spaceMD),
                        decoration: BoxDecoration(
                          color: settings.accessibilityMode == mode
                              ? colors.primary.withValues(alpha: 0.08)
                              : colors.surfaceLight,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMedium,
                          ),
                          border: Border.all(
                            color: settings.accessibilityMode == mode
                                ? colors.primary
                                : colors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              mode.icon,
                              color: settings.accessibilityMode == mode
                                  ? colors.primary
                                  : colors.textSecondary,
                            ),
                            const SizedBox(width: AppTheme.spaceMD),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mode.label,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.spaceXS),
                                  Text(
                                    mode.description,
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              settings.accessibilityMode == mode
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: settings.accessibilityMode == mode
                                  ? colors.primary
                                  : colors.textLight,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          AppearanceSettingsCard(
            title: 'Text size',
            description:
                'Increase reading comfort without breaking page layout consistency.',
            child: Column(
              children: [
                Slider(
                  min: ThemeSettings.minTextScale,
                  max: ThemeSettings.maxTextScale,
                  divisions: 4,
                  label: '${(settings.textScale * 100).round()}%',
                  value: settings.textScale,
                  onChanged: themeManager.updateTextScale,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Smaller',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    Text(
                      '${(settings.textScale * 100).round()}%',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Larger',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          OutlinedButton.icon(
            onPressed: themeManager.reset,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset accessibility settings'),
          ),
        ],
      ),
    );
  }
}
