import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../services/blink_fatigue_service.dart';
import '../services/blink_detection_service.dart';
import '../utils/permission_helper.dart';
import '../utils/blink_detector.dart';

/// Real-time blink and fatigue detection using CNN model
class BlinkFatigueCNNTestPage extends StatefulWidget {
  const BlinkFatigueCNNTestPage({super.key});

  @override
  State<BlinkFatigueCNNTestPage> createState() =>
      _BlinkFatigueCNNTestPageState();
}

class _BlinkFatigueCNNTestPageState extends State<BlinkFatigueCNNTestPage> {
  CameraController? _cameraController;
  List<CameraDescription>? cameras;

  // Test states
  int testPhase = 0; // 0: ready, 1: testing, 2: results
  bool isProcessing = false;
  DateTime? testStartTime;

  // Test timers
  Timer? _testTimer;
  Timer? _blinkTimer;
  Timer? _durationTimer;

  // Test progress and metrics
  double progress = 0;
  int blinkCount = 0;
  int testDuration = 0; // in seconds

  // Blink detector
  BlinkDetector? _blinkDetector;

  // Save state
  bool isSaving = false;
  bool isSaved = false;

  // Results from CNN
  Map<String, dynamic>? predictionResult;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _blinkDetector = BlinkDetector();
    _initializeCameras();
  }

  Future<void> _initializeCameras() async {
    try {
      // Request camera permission first
      if (mounted) {
        final hasPermission = await PermissionHelper.requestCameraPermission(
          context,
        );
        if (!hasPermission) {
          if (mounted) {
            setState(() {
              errorMessage =
                  'Camera permission denied. This test requires camera access.';
            });
          }
          return;
        }
      }

      cameras = await availableCameras();
      if (cameras == null || cameras!.isEmpty) {
        if (mounted) {
          setState(() {
            errorMessage =
                'No camera found on this device. This test requires a camera.';
          });
        }
        return;
      }

      if (cameras!.isNotEmpty && mounted) {
        _initializeCamera();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Camera initialization failed: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _initializeCamera() async {
    if (cameras == null || cameras!.isEmpty) return;

    _cameraController = CameraController(
      cameras![0],
      ResolutionPreset
          .medium, // Lower resolution for better emulator performance
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

  Future<void> _startTest() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showError('Camera not ready');
      return;
    }

    setState(() {
      testPhase = 1;
      progress = 0;
      blinkCount = 0;
      testDuration = 0;
      testStartTime = DateTime.now();
      errorMessage = null;
    });

    // Start real-time blink detection using BlinkDetector
    _blinkDetector?.startDetection(
      _cameraController!,
      (count) {
        if (mounted) {
          setState(() {
            blinkCount = count;
          });
        }
      },
      onError: (error) {
        debugPrint('⚠️ Blink detection error: $error');
      },
    );

    // Test progression (40 seconds for accurate blink detection)
    _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        progress += 2.5; // 100 / 40 seconds = 2.5% per second
      });

      if (progress >= 100) {
        timer.cancel();
        _blinkDetector?.stopDetection();
        _durationTimer?.cancel();
        _captureAndAnalyze();
      }
    });

    // Track test duration
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || testPhase != 1) {
        timer.cancel();
        return;
      }

      setState(() {
        testDuration++;
      });
    });
  }

  Future<void> _captureAndAnalyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showError('Camera not ready');
      setState(() {
        testPhase = 0;
      });
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      // Capture image for CNN analysis
      final XFile imageFile = await _cameraController!.takePicture();

      // Convert to File
      final File imageToAnalyze = File(imageFile.path);

      // Call CNN prediction API WITHOUT saving (use predictDrowsiness instead of submitTest)
      final result = await BlinkFatigueService.predictDrowsiness(
        imageToAnalyze,
      );

      // Store the image file path for later saving
      final directory = await getTemporaryDirectory();
      final savedImagePath = path.join(
        directory.path,
        'blink_test_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await imageToAnalyze.copy(savedImagePath);

      if (mounted) {
        setState(() {
          predictionResult = result;
          predictionResult!['saved_image_path'] =
              savedImagePath; // Store for later save
          testPhase = 2;
          isProcessing = false;
        });
      }

      // Clean up original temporary image
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

  Future<void> _saveResults() async {
    if (isSaving || isSaved || predictionResult == null) return;

    setState(() {
      isSaving = true;
    });

    try {
      // Extract prediction results with null safety
      final prediction =
          predictionResult!['prediction'] as String? ?? 'notdrowsy';
      final confidence =
          (predictionResult!['confidence'] as num?)?.toDouble() ?? 0.0;
      final probabilities =
          predictionResult!['probabilities'] as Map<String, dynamic>? ??
          {'drowsy': 0.0, 'notdrowsy': 1.0};
      final drowsinessProb =
          (probabilities['drowsy'] as num?)?.toDouble() ?? 0.0;

      // Get actual blink count from detector
      final actualBlinkCount = _blinkDetector?.blinkCount ?? blinkCount;

      // Determine fatigue level
      String fatigueLevel;
      if (drowsinessProb > 0.6) {
        fatigueLevel = 'High Fatigue';
      } else if (drowsinessProb > 0.4) {
        fatigueLevel = 'Moderate Fatigue';
      } else {
        fatigueLevel = 'Alert';
      }

      // Submit test using new BlinkDetectionService
      final result = await BlinkDetectionService.submitTest(
        blinkCount: actualBlinkCount,
        durationSeconds: testDuration,
        drowsinessProbability: drowsinessProb,
        confidenceScore: confidence,
        fatigueLevel: fatigueLevel,
      );

      if (mounted) {
        setState(() {
          isSaved = true;
          isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Results saved successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isSaving = false;
        });

        final errorMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $errorMsg'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  int getBlinkRate() {
    if (testDuration == 0) return 0;
    final actualBlinkCount = _blinkDetector?.blinkCount ?? blinkCount;
    return ((actualBlinkCount / testDuration) * 60).round();
  }

  void _retakeTest() {
    _blinkDetector?.reset();
    setState(() {
      testPhase = 0;
      predictionResult = null;
      errorMessage = null;
      testStartTime = null;
      progress = 0;
      blinkCount = 0;
      testDuration = 0;
      isSaving = false;
      isSaved = false;
    });
    _testTimer?.cancel();
    _durationTimer?.cancel();
  }

  void _goToDashboard() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    _blinkDetector?.dispose();
    _testTimer?.cancel();
    _durationTimer?.cancel();
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
      body: SafeArea(child: testPhase == 2 ? _buildResults() : _buildCamera()),
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
        Positioned.fill(child: CameraPreview(_cameraController!)),

        // Processing/Testing overlay
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

        // Test progress overlay (during test)
        if (testPhase == 1 && !isProcessing)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Testing in Progress...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 24,
                          child: LinearProgressIndicator(
                            value: progress / 100,
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${progress.toInt()}% Complete',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Metrics during test
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              children: [
                                Icon(
                                  Icons.visibility,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '$blinkCount',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Blinks',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: 48),
                            Column(
                              children: [
                                Icon(
                                  Icons.timer,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '${testDuration}s',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Duration',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                  const Icon(Icons.visibility, size: 48, color: Colors.white),
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
                    "The test will run for 40 seconds to accurately measure blink rate and fatigue levels",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: isProcessing ? null : _startTest,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("Start Test (40s)"),
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

    // Use null-safe operators with default values
    final prediction =
        predictionResult!['prediction'] as String? ?? 'notdrowsy';
    final confidence =
        (predictionResult!['confidence'] as num?)?.toDouble() ?? 0.0;
    final fatigueLevel =
        predictionResult!['fatigue_level'] as String? ?? 'Unknown';
    final alertTriggered =
        predictionResult!['alert_triggered'] as bool? ?? false;
    final probabilities =
        predictionResult!['probabilities'] as Map<String, dynamic>? ??
        {'drowsy': 0.0, 'notdrowsy': 1.0};

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

          const SizedBox(height: 16),

          // Blink Metrics
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Blink Rate',
                  value: '${getBlinkRate()}/min',
                  icon: Icons.visibility,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Total Blinks',
                  value: (_blinkDetector?.blinkCount ?? blinkCount).toString(),
                  icon: Icons.remove_red_eye,
                  color: Colors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Test Duration
          _buildMetricCard(
            title: 'Test Duration',
            value: '${testDuration}s',
            icon: Icons.timer,
            color: Colors.teal,
          ),

          const SizedBox(height: 24),

          // Save Results Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSaving || isSaved ? null : _saveResults,
              icon: Icon(isSaved ? Icons.check_circle : Icons.save),
              label: Text(
                isSaving
                    ? 'Saving...'
                    : (isSaved ? 'Results Saved' : 'Save Results'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isSaved ? Colors.green[600] : Colors.blue[600],
                disabledBackgroundColor: Colors.grey[400],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

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
                child: OutlinedButton.icon(
                  onPressed: _goToDashboard,
                  icon: const Icon(Icons.home),
                  label: const Text('Dashboard'),
                  style: OutlinedButton.styleFrom(
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

          // Information note (only show if saved)
          if (isSaved)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Results saved to your profile. View history in Results page.',
                      style: TextStyle(fontSize: 13, color: Colors.green[900]),
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

          const SizedBox(height: 24),

          // Save confirmation message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[300]!, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Results saved successfully!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[900],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      testPhase = 0;
                      predictionResult = null;
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('Test Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.home, size: 20),
                  label: const Text('Return Home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
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
