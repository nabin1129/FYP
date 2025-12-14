import 'package:flutter/material.dart';
import 'package:netracare/pages/profile_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Pages for navigation
    final List<Widget> pages = [
      _homePage(), // Home Dashboard Content
      _reportsPage(), // Reports Page Placeholder
      const ProfilePage(), // Profile Page
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),

      // Switch view instead of navigating
      body: pages[selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          setState(() => selectedIndex = index);
        },
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
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
  // HOME PAGE CONTENT
  // ---------------------------
  Widget _homePage() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // UPCOMING CHECKUP
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 38,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 15),
                  const Expanded(
                    child: Text(
                      "Upcoming Checkup\nJune 15, 2025",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Eye Health Status
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.green.shade100,
                    child: const Text(
                      "85",
                      style: TextStyle(
                        color: Colors.green,
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
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              "Available Tests",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            _testCard(
              Icons.visibility,
              "Visual Acuity Test",
              "Measures clarity of vision at various distances.",
            ),
            _testCard(
              Icons.remove_red_eye,
              "Eye Tracking Test",
              "Analyzes eye movement patterns.",
            ),
            _testCard(
              Icons.bedtime,
              "Blink & Fatigue Test",
              "Evaluates blink rate & eye fatigue.",
            ),
            _testCard(
              Icons.flash_on,
              "Pupil Reflex Test",
              "Tests eye response to light.",
            ),
            _testCard(
              Icons.color_lens,
              "Colour Vision Test",
              "Detects colour deficiencies.",
            ),

            const SizedBox(height: 25),

            // DOCTOR CONSULTATION
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [Color(0xFF4FACFE), Color(0xFF5B76F7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.video_camera_front,
                        color: Colors.white,
                        size: 28,
                      ),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {},
                      child: const Text(
                        "Book Consultation",
                        style: TextStyle(
                          color: Color(0xFF3554F4),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  // ---------------------------
  // SIMPLE REPORTS PAGE (placeholder)
  // ---------------------------
  Widget _reportsPage() {
    return const Center(
      child: Text(
        "Reports Page will be here.",
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ---------------------------
  // Test Card Widget
  // ---------------------------
  Widget _testCard(IconData icon, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black12.withOpacity(0.07), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 34, color: Colors.blue),
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
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          TextButton(onPressed: () {}, child: const Text("Start")),
        ],
      ),
    );
  }
}
