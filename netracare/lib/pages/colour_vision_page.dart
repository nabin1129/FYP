import 'package:flutter/material.dart';
import 'colour_vision_test_page.dart';

class ColourVisionPage extends StatefulWidget {
  const ColourVisionPage({super.key});

  @override
  State<ColourVisionPage> createState() => _ColourVisionPageState();
}

class _ColourVisionPageState extends State<ColourVisionPage> {
  String step = 'intro'; // intro | setup

  void proceed() {
    if (step == 'intro') {
      setState(() => step = 'setup');
    }
  }

  void goBack() {
    if (step != 'intro') {
      setState(() {
        if (step == 'setup') {
          step = 'intro';
        }
      });
    } else {
      Navigator.pop(context);
    }
  }

  void startTest() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ColourVisionTestPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Stack(
          children: [
            // Back button
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: goBack,
              ),
            ),

            // Main Card
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

  // ============ INTRO SCREEN ============
  Widget _introUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.palette, size: 32, color: Colors.purple[600]),
        ),
        const SizedBox(height: 20),
        const Text(
          "Colour Vision Test",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1f2937),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "This test uses Ishihara plates to detect colour vision deficiencies, particularly red-green colour blindness.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF6b7280), height: 1.5),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Before you begin:",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple[800],
                ),
              ),
              const SizedBox(height: 12),
              _checkItem(
                "Ensure you are in a well-lit room with natural lighting if possible",
              ),
              const SizedBox(height: 8),
              _checkItem(
                "Adjust your screen brightness to a comfortable level",
              ),
              const SizedBox(height: 8),
              _checkItem(
                "View the screen from approximately 75cm (arm's length)",
              ),
              const SizedBox(height: 8),
              _alertItem(
                "This is a screening test only. Consult an eye specialist for diagnosis",
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: proceed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[600],
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Continue",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============ SETUP SCREEN ============
  Widget _setupUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.info, size: 32, color: Colors.purple[600]),
        ),
        const SizedBox(height: 20),
        const Text(
          "Test Instructions",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1f2937),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "You will see a series of Ishihara colour plates. For each plate, select the number you see as quickly as possible.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF6b7280), height: 1.5),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple[50],
            border: Border.all(color: Colors.purple[200]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb, color: Colors.purple[600], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Make sure your screen is properly calibrated for accurate results.",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.purple[900],
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: startTest,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Start Test",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _checkItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle, size: 18, color: Colors.green[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.purple[700],
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _alertItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning, size: 18, color: Colors.amber[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.purple[700],
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
