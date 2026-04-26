import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/features/auth/auth.dart';
import 'package:netracare/features/profile/profile.dart';
import 'package:netracare/features/reports/reports.dart';
import 'package:netracare/features/shared/widgets/shared_widgets.dart';
import 'package:netracare/features/tests/tests.dart';
import 'package:netracare/services/api_service.dart';
import 'package:netracare/models/user_model.dart';
import 'package:netracare/widgets/profile_widgets.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? user;
  bool isLoading = true;
  String? errorMessage;

  // Controllers maintained for state updates after editing
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController ageController;
  String? selectedSex;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    emailController = TextEditingController();
    ageController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    ageController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ApiService.getProfile();
      if (!mounted) return;

      setState(() {
        user = profile;
        nameController.text = profile.name;
        emailController.text = profile.email;
        ageController.text = profile.age?.toString() ?? '';
        selectedSex = profile.sex;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      final errorMsg = e.toString().replaceAll('Exception:', '').trim();

      // Check if it's a session expiration error
      if (errorMsg.contains('Session expired') || errorMsg.contains('401')) {
        setState(() {
          isLoading = false;
        });
        _showSessionExpiredDialog();
      } else {
        setState(() {
          isLoading = false;
          errorMessage = errorMsg;
        });
      }
    }
  }

  void _showSessionExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: AppTheme.warning),
            const SizedBox(width: 8),
            const Text('Session Expired'),
          ],
        ),
        content: const Text(
          'Your session has expired. Please login again to continue.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await ApiService.deleteToken();
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (_) => false,
              );
            },
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // LOADING
    if (isLoading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ERROR (Show generic error for non-auth errors)
    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: colors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.error),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      errorMessage = null;
                      isLoading = true;
                    });
                    _loadProfile();
                  },
                  child: const Text("Retry"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // SUCCESS
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    "Profile",
                    role: AppTextRole.title,
                    color: colors.textDark,
                    fontWeight: FontWeight.bold,
                  ),
                  const SizedBox(height: 4),
                  AppText(
                    "Manage your account settings",
                    role: AppTextRole.bodySecondary,
                  ),
                ],
              ),
            ),

            // Gradient Profile Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GradientProfileCard(
                user: user!,
                onEditProfile: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileSettingsScreen(user: user!),
                    ),
                  );
                  if (result != null && result is User && mounted) {
                    setState(() {
                      user = result;
                      nameController.text = result.name;
                      emailController.text = result.email;
                      ageController.text = result.age?.toString() ?? '';
                      selectedSex = result.sex;
                    });
                  }
                },
              ),
            ),

            const SizedBox(height: 32),

            // Account Settings Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Account Settings",
                    style: TextStyle(
                      fontSize: AppTheme.fontXL,
                      fontWeight: FontWeight.w600,
                      color: colors.textSubtle,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SettingsGroupCard(
                    children: [
                      SettingsTile(
                        icon: Icons.person_outline,
                        iconColor: AppTheme.info,
                        title: "Personal Information",
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProfileSettingsScreen(user: user!),
                            ),
                          );
                          if (result != null && result is User && mounted) {
                            setState(() {
                              user = result;
                              nameController.text = result.name;
                              emailController.text = result.email;
                              ageController.text = result.age?.toString() ?? '';
                              selectedSex = result.sex;
                            });
                          }
                        },
                      ),
                      const Divider(height: 1, indent: 56),
                      SettingsTile(
                        icon: Icons.lock_outline,
                        iconColor: AppTheme.categoryPurple,
                        title: "Privacy & Security",
                        onTap: () {},
                      ),
                      const Divider(height: 1, indent: 56),
                      SettingsTile(
                        icon: Icons.notifications_outlined,
                        iconColor: AppTheme.warning,
                        title: "Notifications",
                        onTap: () {
                          Navigator.pushNamed(context, '/notifications');
                        },
                      ),
                      const Divider(height: 1, indent: 56),
                      SettingsTile(
                        icon: Icons.accessibility_new_outlined,
                        iconColor: AppTheme.primary,
                        title: "Accessibility",
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/accessibility-settings',
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Health Data Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Health Data",
                    style: TextStyle(
                      fontSize: AppTheme.fontXL,
                      fontWeight: FontWeight.w600,
                      color: colors.textSubtle,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SettingsGroupCard(
                    children: [
                      SettingsTile(
                        icon: Icons.history,
                        iconColor: AppTheme.success,
                        title: "Test History",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ResultsReportPage(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 56),
                      SettingsTile(
                        icon: Icons.medical_services_outlined,
                        iconColor: AppTheme.error,
                        title: "Medical Records",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MedicalRecordsPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: LogoutButton(
                onLogout: () async {
                  final nav = Navigator.of(context);
                  await ApiService.deleteToken();
                  nav.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (_) => false,
                  );
                },
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
