import 'package:flutter/material.dart';
import 'blink_fatigue_cnn_test_page.dart';
import '../services/api_service.dart';

class BlinkFatiguePage extends StatefulWidget {
  const BlinkFatiguePage({super.key});

  @override
  State<BlinkFatiguePage> createState() => _BlinkFatiguePageState();
}

class _BlinkFatiguePageState extends State<BlinkFatiguePage> {
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

  Future<void> startTest() async {
    // Check if user is authenticated
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          _showSessionExpiredDialog();
        }
        return;
      }

      // Token exists, proceed to test
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const BlinkFatigueCNNTestPage(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSessionExpiredDialog();
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
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to dashboard
              // Navigate to login
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (route) => false);
            },
            child: const Text('Login'),
          ),
        ],
      ),
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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.orange.shade100, Colors.red.shade100],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.visibility_off,
            size: 32,
            color: Colors.orange[700],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Blink & Fatigue Test",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1f2937),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "This test measures your blink rate and detects signs of eye fatigue, which are important indicators of digital eye strain and overall eye health.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF6b7280), height: 1.5),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.orange.shade50, Colors.red.shade50],
            ),
            border: Border.all(color: Colors.orange.shade200),
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
                  color: Colors.orange[800],
                ),
              ),
              const SizedBox(height: 12),
              _checkItem("Find a comfortable, well-lit environment"),
              const SizedBox(height: 8),
              _checkItem("Sit approximately 50-60cm from your device"),
              const SizedBox(height: 8),
              _checkItem("Blink naturally - don't force or suppress blinking"),
              const SizedBox(height: 8),
              _checkItem("The test will take approximately 40 seconds"),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.orange[600]!, Colors.red[600]!],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: proceed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.orange.shade100, Colors.red.shade100],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.videocam, size: 32, color: Colors.orange[700]),
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
          "We'll need access to your camera to monitor your blink patterns and detect eye fatigue indicators.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF6b7280), height: 1.5),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.yellow[50],
            border: Border.all(color: Colors.yellow[200]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning, color: Colors.yellow[700], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Your camera will only be used during this test. No recordings are saved or shared. The AI analyses your blink patterns in real-time.",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.yellow[900],
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
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.orange[600]!, Colors.red[600]!],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: startTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "Enable Camera & Start Test",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
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
              color: Colors.orange[700],
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
