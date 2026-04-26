import 'package:flutter/material.dart';

import 'package:netracare/config/app_theme.dart';
import 'package:netracare/features/shared/widgets/shared_widgets.dart';
import '../models/user_model.dart';

class GradientProfileCard extends StatelessWidget {
  const GradientProfileCard({
    super.key,
    required this.user,
    required this.onEditProfile,
  });

  final User user;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppContainer(
      padding: const EdgeInsets.all(24),
      gradient: colors.primaryGradient,
      borderRadius: BorderRadius.circular(24),
      boxShadow: AppTheme.adaptiveElevatedShadow(context),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.32),
                width: 3,
              ),
            ),
            child: CircleAvatar(
              radius: 42,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onEditProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: colors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Edit Profile'),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsGroupCard extends StatelessWidget {
  const SettingsGroupCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppCard(
      padding: EdgeInsets.zero,
      border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      child: Column(children: children),
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AppText(
                  title,
                  role: AppTextRole.body,
                  color: colors.textDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(Icons.chevron_right, color: colors.textSecondary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onLogout,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: colors.error, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Log Out',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.error,
          ),
        ),
      ),
    );
  }
}
