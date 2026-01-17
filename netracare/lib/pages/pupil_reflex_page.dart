import 'package:flutter/material.dart';
import 'pupil_reflex_test_page.dart';

class PupilReflexPage extends StatefulWidget {
  const PupilReflexPage({super.key});

  @override
  State<PupilReflexPage> createState() => _PupilReflexPageState();
}

class _PupilReflexPageState extends State<PupilReflexPage> {
  String step = 'intro'; // intro | setup | warning

  void proceed() {
    if (step == 'intro') {
      setState(() => step = 'setup');
    } else if (step == 'setup') {
      setState(() => step = 'warning');
    }
  }

  void goBack() {
    if (step != 'intro') {
      setState(() {
        if (step == 'setup') {
          step = 'intro';
        } else if (step == 'warning') {
          step = 'setup';
        }
      });
    } else {
      Navigator.pop(context);
    }
  }

  void startTest() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PupilReflexTestPage()),
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
                child: step == 'intro'
                    ? _introUI()
                    : step == 'setup'
                    ? _setupUI()
                    : _warningUI(),
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
            color: Colors.blue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.flash_on, size: 32, color: Colors.blue[600]),
        ),
        const SizedBox(height: 20),
        const Text(
          "Pupil Reflex Test",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1f2937),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "This test will evaluate how your pupils respond to changes in light, which can indicate important aspects of your eye health.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF6b7280), height: 1.5),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: proceed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
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
            color: Colors.blue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.videocam, size: 32, color: Colors.blue[600]),
        ),
        const SizedBox(height: 20),
        const Text(
          "Camera Setup",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1f2937),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "We'll need access to your camera to observe your pupil reactions during the test.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF6b7280), height: 1.5),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            border: Border.all(color: Colors.amber[200]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_rounded, color: Colors.amber[600], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Your camera will only be used during this test. No recordings are saved or shared.",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.amber[900],
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
            onPressed: proceed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
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

  // ============ WARNING SCREEN ============
  Widget _warningUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.warning_rounded,
            size: 32,
            color: Colors.amber[600],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Before You Begin",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1f2937),
          ),
        ),
        const SizedBox(height: 20),
        _checkItem('Find a dimly lit, quiet room'),
        const SizedBox(height: 12),
        _checkItem(
          'Position yourself approximately 1 arm\'s length from your device',
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red[50],
            border: Border.all(color: Colors.red[200]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_rounded, color: Colors.red[600], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "This test will use brief flashes of light. Do not take this test if you have photosensitive epilepsy.",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red[900],
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
        Icon(Icons.check_circle, size: 20, color: Colors.green[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF4b5563),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
