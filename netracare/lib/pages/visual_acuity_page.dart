import 'package:flutter/material.dart';

class VisualAcuityPage extends StatefulWidget {
  const VisualAcuityPage({super.key});

  @override
  State<VisualAcuityPage> createState() => _VisualAcuityPageState();
}

class _VisualAcuityPageState extends State<VisualAcuityPage> {
  String step = 'intro'; // intro | setup

  void proceed() {
    if (step == 'intro') {
      setState(() => step = 'setup');
    }
  }

  void goBack() {
    if (step == 'setup') {
      // Go back to intro screen
      setState(() => step = 'intro');
    } else {
      // Exit page → back to Dashboard
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Stack(
          children: [
            // -------- BACK BUTTON --------
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: goBack,
              ),
            ),

            // -------- MAIN CARD --------
            Center(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 380),
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: step == 'intro' ? _introUI() : _setupUI(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- INTRO SCREEN ----------------
  Widget _introUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.remove_red_eye,
            size: 56, color: Colors.blue),
        const SizedBox(height: 16),
        const Text(
          "Visual Acuity Test",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          "This test will measure how clearly you can see letters at different sizes, similar to an eye chart at the doctor’s office.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),

        _infoRow("Find a quiet, well-lit room"),
        _infoRow("Position yourself at arm’s length"),
        _infoRow("Wear distance glasses if applicable"),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: proceed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Start Test"),
          ),
        ),
      ],
    );
  }

  // ---------------- CAMERA SETUP SCREEN ----------------
  Widget _setupUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "Camera Setup",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          "Camera access is required during the test.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 30),

        Container(
          height: 120,
          width: 120,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.camera_alt,
            size: 48,
            color: Colors.grey,
          ),
        ),

        const SizedBox(height: 30),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // 🔒 STOP HERE (Backend + AI later)
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Enable Camera & Start"),
          ),
        ),
      ],
    );
  }

  // ---------------- HELPER ----------------
  Widget _infoRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle,
              color: Colors.blue, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
