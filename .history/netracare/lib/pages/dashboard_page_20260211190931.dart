import 'package:flutter/material.dart';
import 'package:netracare/pages/profile_page.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/models/consultation/consultation_model.dart';
import 'visual_acuity_page.dart';
import 'eye_tracking_page.dart';
import 'pupil_reflex_page.dart';
import 'colour_vision_page.dart';
import 'blink_fatigue_page.dart';
import 'results_report_page.dart';
import 'consultation/doctor_consultation_page.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedIndex = 0;
  Consultation? nextConsultation;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _homePage(),
      _reportsPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: pages[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => setState(() => selectedIndex = index),
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textLight,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.insert_drive_file),
            label: "Reports",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
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
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nextConsultation!.date,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          nextConsultation!.doctorName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      "No Upcoming Consultation\nBook a consultation with a doctor",
                      style: TextStyle(
                        fontSize: 15,
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
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Text(
              "Good Eye Health\n2 tests pending",
              style: TextStyle(
                fontSize: 15,
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
                  fontSize: 20,
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
                );
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
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
