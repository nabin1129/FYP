import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../services/blink_fatigue_service.dart';

/// Real-time blink and fatigue detection using CNN model
class BlinkFatigueCNNTestPage extends StatefulWidget {
  const BlinkFatigueCNNTestPage({super.key});

  @override
  State<BlinkFatigueCNNTestPage> createState() => _BlinkFatigueCNNTestPageState();
}

class _BlinkFatigueCNNTestPageState extends State<BlinkFatigueCNNTestPage> {
  CameraController? _cameraController;
  List<CameraDescription>? cameras;

  // Test states
  int testPhase = 0; // 0: ready, 1: testing, 2: results
  bool isProcessing = false;
  DateTime? testStartTime;
  
  // Results from CNN
  Map<String, dynamic>? predictionResult;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCameras();
  }

  Future<void> _initializeCameras() async {
    try {
      cameras = await availableCameras();
      if (cameras != null && cameras!.isNotEmpty && mounted) {
        _initializeCamera();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to initialize camera: $e';
        });
      }
    }
  }

  Future<void> _initializeCamera() async {
    if (cameras == null || cameras!.isEmpty) return;

    _cameraController = CameraController(
      cameras![0],
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to initialize camera: $e';
        });
      }
    }
  }

  Future<void> _captureAndAnalyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showError('Camera not ready');
      return;
    }

    setState(() {
      testPhase = 1;
      isProcessing = true;
      testStartTime = DateTime.now();
      errorMessage = null;
    });

    try {
      // Capture image
      final XFile imageFile = await _cameraController!.takePicture();
      
      // Convert to File
      final File imageToAnalyze = File(imageFile.path);

      // Call CNN model prediction API
      final result = await BlinkFatigueService.submitTest(
        imageFile: imageToAnalyze,
        testDuration: testStartTime != null 
            ? DateTime.now().difference(testStartTime!).inSeconds.toDouble()
            : null,
      );

      if (mounted) {
        setState(() {
          predictionResult = result;
          testPhase = 2;
          isProcessing = false;
        });
      }

      // Clean up temporary image
      try {
        await imageToAnalyze.delete();
      } catch (_) {}

    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      
      if (mounted) {
        // Check if it's a session expiration error
        if (errorMsg.contains('Session expired') || errorMsg.contains('401')) {
          _showSessionExpiredDialog();
        } else {
          setState(() {
            errorMessage = errorMsg;
            isProcessing = false;
            testPhase = 0;
          });
          _showError(errorMessage ?? 'Analysis failed');
        }
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
              // Close dialog and go back to dashboard, then to login
              Navigator.of(context).popUntil((route) => route.isFirst);
              Navigator.of(context).pushReplacementNamed('/login');
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  void _retakeTest() {
    setState(() {
      testPhase = 0;
      predictionResult = null;
      errorMessage = null;
      testStartTime = null;
    });
  }

  void _goToDashboard() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text("Blink & Fatigue Detection"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: testPhase == 2 ? _buildResults() : _buildCamera(),
      ),
    );
  }

  // ============ CAMERA UI ============
  Widget _buildCamera() {
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        // Camera preview
        Positioned.fill(
          child: CameraPreview(_cameraController!),
        ),

        // Processing overlay
        if (isProcessing)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Analyzing with CNN model...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Instructions overlay
        if (!isProcessing && testPhase == 0)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.visibility,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Position your face in the frame",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Make sure your eyes are clearly visible and well-lit",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: isProcessing ? null : _captureAndAnalyze,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Capture & Analyze"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[600],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ============ RESULTS UI ============
  Widget _buildResults() {
    if (predictionResult == null) {
      return const Center(child: Text('No results available'));
    }

    final prediction = predictionResult!['prediction'] as String;
    final confidence = (predictionResult!['confidence'] as num).toDouble();
    final fatigueLevel = predictionResult!['fatigue_level'] as String;
    final alertTriggered = predictionResult!['alert_triggered'] as bool;
    final probabilities = predictionResult!['probabilities'] as Map<String, dynamic>;
    
    final isDrowsy = prediction == 'drowsy';
    final statusColor = isDrowsy ? Colors.red : Colors.green;
    final statusIcon = isDrowsy ? Icons.warning_amber : Icons.check_circle;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          
          // Status Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  statusColor.withOpacity(0.2),
                  statusColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
            ),
            child: Column(
              children: [
                Icon(statusIcon, size: 64, color: statusColor),
                const SizedBox(height: 16),
                Text(
                  isDrowsy ? 'Drowsiness Detected' : 'Alert State',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  fatigueLevel,
                  style: TextStyle(
                    fontSize: 18,
                    color: statusColor.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Alert Warning (if triggered)
          if (alertTriggered)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[300]!, width: 2),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red[700], size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'High fatigue detected! Consider taking a break.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.red[900],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (alertTriggered) const SizedBox(height: 24),

          // Confidence Score
          _buildMetricCard(
            title: 'Confidence Score',
            value: '${(confidence * 100).toStringAsFixed(1)}%',
            icon: Icons.psychology,
            color: Colors.blue,
          ),

          const SizedBox(height: 16),

          // Probabilities
          _buildProbabilitiesCard(probabilities),

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _retakeTest,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Test Again'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _goToDashboard,
                  icon: const Icon(Icons.home),
                  label: const Text('Dashboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Information note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Results saved to your profile. View history in Results page.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProbabilitiesCard(Map<String, dynamic> probabilities) {
    final drowsyProb = (probabilities['drowsy'] as num).toDouble();
    final notDrowsyProb = (probabilities['notdrowsy'] as num).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detection Probabilities',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          
          // Drowsy probability
          _buildProbabilityBar(
            label: 'Drowsy',
            probability: drowsyProb,
            color: Colors.red,
          ),
          
          const SizedBox(height: 16),
          
          // Not drowsy probability
          _buildProbabilityBar(
            label: 'Alert',
            probability: notDrowsyProb,
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildProbabilityBar({
    required String label,
    required double probability,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              '${(probability * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: probability,
            minHeight: 12,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
