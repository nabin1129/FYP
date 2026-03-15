import 'package:flutter/material.dart';
import 'package:netracare/pages/profile_page.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/services/api_service.dart';
import 'package:netracare/models/consultation/consultation_model.dart';
import 'package:netracare/services/consultation_service.dart';
import 'package:netracare/services/notification_service.dart';
import 'visual_acuity_page.dart';
import 'eye_tracking_page.dart';
import 'pupil_reflex_page.dart';
import 'colour_vision_page.dart';
import 'blink_fatigue_page.dart';
import 'results_report_page.dart';
import 'consultation/doctor_consultation_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedIndex = 0;
  Consultation? nextConsultation;

  final ConsultationService _consultationService = ConsultationService();
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await Future.wait([_loadNextConsultation(), _loadNotificationCount()]);

    // Initialize notification polling
    _notificationService.initialize();
  }

  Future<void> _loadNextConsultation() async {
    try {
      final nextScheduled = await _consultationService
          .getNextScheduledConsultationAsync();
      if (mounted) {
        setState(() {
          nextConsultation = nextScheduled;
        });
      }
    } catch (e) {
      // Fallback to sync version
      final consultationService = ConsultationService();
      final nextScheduled = consultationService.getNextScheduledConsultation();
      if (mounted) {
        setState(() {
          nextConsultation = nextScheduled;
        });
      }
    }
  }

  Future<void> _loadNotificationCount() async {
    try {
      await _notificationService.getUnreadCount();
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _homePage(),
      _reportsPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      body: pages[selectedIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ---------------------------
  // APP BAR
  // ---------------------------
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: AppTheme.surface,
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.remove_red_eye_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Netra Care',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: AppTheme.fontLG,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: GestureDetector(
            onTap: _showProfileMenu,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLarge),
          ),
        ),
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppTheme.spaceLG),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 32),
            ),
            const SizedBox(height: AppTheme.spaceMD),
            const Text(
              'My Account',
              style: TextStyle(
                fontSize: AppTheme.fontXL,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLG),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.settings_outlined,
                color: AppTheme.textSecondary,
              ),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                setState(() => selectedIndex = 2);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.help_outline,
                color: AppTheme.textSecondary,
              ),
              title: const Text('Help & Support'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.error),
              title: const Text(
                'Logout',
                style: TextStyle(color: AppTheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _showLogoutDialog();
              },
            ),
            const SizedBox(height: AppTheme.spaceMD),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to logout from your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await ApiService.deleteToken();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMD,
            vertical: AppTheme.spaceSM,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                0,
                Icons.dashboard_outlined,
                Icons.dashboard,
                'Home',
              ),
              _buildNavItem(
                1,
                Icons.insert_drive_file_outlined,
                Icons.insert_drive_file,
                'Reports',
              ),
              _buildNavItem(2, Icons.person_outline, Icons.person, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final isSelected = selectedIndex == index;

    return InkWell(
      onTap: () => setState(() => selectedIndex = index),
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMD,
          vertical: AppTheme.spaceSM,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: AppTheme.spaceSM),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: AppTheme.fontSM,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------
  // HOME PAGE
  // ---------------------------
  Widget _homePage() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _upcomingCheckup(),
            const SizedBox(height: 20),
            _eyeHealthStatus(),
            const SizedBox(height: 25),
            const Text(
              "Available Tests",
              style: TextStyle(fontSize: AppTheme.fontXXL, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // VISUAL ACUITY TEST
            _testCard(
              Icons.visibility,
              "Visual Acuity Test",
              "Measures clarity of vision at various distances.",
              onStart: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VisualAcuityPage()),
                );
              },
            ),

            _testCard(
              Icons.remove_red_eye,
              "Eye Tracking Test",
              "Analyzes eye movement patterns.",
              onStart: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EyeTrackingPage()),
                );
              },
            ),

            _testCard(
              Icons.bedtime,
              "Blink & Fatigue Test",
              "Evaluates blink rate & eye fatigue.",
              onStart: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BlinkFatiguePage()),
                );
              },
            ),

            _testCard(
              Icons.flash_on,
              "Pupil Reflex Test",
              "Tests eye response to light.",
              onStart: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PupilReflexPage()),
                );
              },
            ),

            _testCard(
              Icons.color_lens,
              "Colour Vision Test",
              "Detects colour deficiencies.",
              onStart: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ColourVisionPage()),
                );
              },
            ),

            const SizedBox(height: 25),
            _doctorConsultation(),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  // ---------------------------
  // COMPONENTS
  // ---------------------------
  Widget _upcomingCheckup() {
    return InkWell(
      onTap: nextConsultation != null
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DoctorConsultationPage(),
                ),
              );
            }
          : null,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: nextConsultation != null
              ? AppTheme.testIconBackground
              : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: nextConsultation != null
                ? AppTheme.primaryLight.withOpacity(0.3)
                : AppTheme.textLight.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              nextConsultation != null
                  ? Icons.calendar_today
                  : Icons.calendar_today_outlined,
              size: 38,
              color: nextConsultation != null
                  ? AppTheme.primary
                  : AppTheme.textLight,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: nextConsultation != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Upcoming Consultation",
                          style: TextStyle(
                            fontSize: AppTheme.fontBody,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nextConsultation!.date,
                          style: const TextStyle(
                            fontSize: AppTheme.fontXL,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          nextConsultation!.doctorName,
                          style: const TextStyle(
                            fontSize: AppTheme.fontSM,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      "No Upcoming Consultation\nBook a consultation with a doctor",
                      style: TextStyle(
                        fontSize: AppTheme.fontBody,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
            ),
            if (nextConsultation != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(
                  nextConsultation!.type == ConsultationType.videoCall
                      ? Icons.videocam
                      : Icons.chat_bubble_outline,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _eyeHealthStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppTheme.success.withOpacity(0.1),
            child: const Text(
              "85",
              style: TextStyle(
                color: AppTheme.success,
                fontWeight: FontWeight.bold,
                fontSize: AppTheme.fontTitle,
              ),
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Text(
              "Good Eye Health\n2 tests pending",
              style: TextStyle(
                fontSize: AppTheme.fontBody,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _doctorConsultation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        gradient: AppTheme.primaryGradient,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.video_camera_front, color: Colors.white, size: 28),
              SizedBox(width: 10),
              Text(
                "Doctor Consultation",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AppTheme.fontXXL,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            "Connect with eye care specialists for personalized advice.",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DoctorConsultationPage(),
                  ),
                ).then((_) {
                  // Reload consultations when returning
                  _loadNextConsultation();
                });
              },
              child: const Text(
                "Book Consultation",
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------
  // REPORTS PAGE
  // ---------------------------
  Widget _reportsPage() {
    return const ResultsReportPage();
  }

  // ---------------------------
  // TEST CARD
  // ---------------------------
  Widget _testCard(
    IconData icon,
    String title,
    String description, {
    required VoidCallback onStart,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          // Standardized icon container with consistent color
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.testIconBackground,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Icon(icon, size: 24, color: AppTheme.testIconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: AppTheme.fontLG,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
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
          TextButton(
            onPressed: onStart,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.testIconColor,
              backgroundColor: AppTheme.testIconBackground,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMD,
                vertical: AppTheme.spaceSM,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
            ),
            child: const Text(
              "Start",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
