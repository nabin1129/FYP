import 'package:flutter/material.dart';
import 'package:netracare/pages/login_page.dart';
import 'package:netracare/pages/profile/profile_settings_screen.dart';
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
            Icon(Icons.warning_amber, color: Colors.orange[700]),
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
              await ApiService.deleteToken();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
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
    // LOADING
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ERROR (Show generic error for non-auth errors)
    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
                  const Text(
                    "Profile",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Manage your account settings",
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
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
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SettingsGroupCard(
                    children: [
                      SettingsTile(
                        icon: Icons.person_outline,
                        iconColor: const Color(0xFF3B82F6),
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
                        iconColor: const Color(0xFF8B5CF6),
                        title: "Privacy & Security",
                        onTap: () {},
                      ),
                      const Divider(height: 1, indent: 56),
                      SettingsTile(
                        icon: Icons.notifications_outlined,
                        iconColor: const Color(0xFFF59E0B),
                        title: "Notifications",
                        onTap: () {},
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
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SettingsGroupCard(
                    children: [
                      SettingsTile(
                        icon: Icons.history,
                        iconColor: const Color(0xFF10B981),
                        title: "Test History",
                        onTap: () {},
                      ),
                      const Divider(height: 1, indent: 56),
                      SettingsTile(
                        icon: Icons.medical_services_outlined,
                        iconColor: const Color(0xFFEF4444),
                        title: "Medical Records",
                        onTap: () {},
                      ),
                      const Divider(height: 1, indent: 56),
                      SettingsTile(
                        icon: Icons.bar_chart_outlined,
                        iconColor: const Color(0xFF06B6D4),
                        title: "Health Analytics",
                        onTap: () {},
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
                  await ApiService.deleteToken();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
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
