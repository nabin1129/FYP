import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../services/blink_fatigue_service.dart';
import '../utils/permission_helper.dart';

/// Simulation-based blink detection test with save capability
/// This version simulates blink detection and allows saving results to the database.
class BlinkFatigueTestPage extends StatefulWidget {
  const BlinkFatigueTestPage({super.key});

  @override
  State<BlinkFatigueTestPage> createState() => _BlinkFatigueTestPageState();
}

class _BlinkFatigueTestPageState extends State<BlinkFatigueTestPage> {
  CameraController? _cameraController;
  List<CameraDescription>? cameras;

  int testPhase = 0; // 0: ready, 1: testing, 2: results
  double progress = 0;
  bool isTestComplete = false;
  int blinkCount = 0;
  double fatigueLevel = 0;
  int testDuration = 0;
  bool isSaving = false;
  bool isSaved = false;
  bool _cameraPermissionDenied = false;
  String _cameraErrorMessage = '';

  Timer? _testTimer;
  Timer? _blinkTimer;
  Timer? _durationTimer;
  Timer? _fatigueTimer;

  @override
  void initState() {
    super.initState();
    _initializeCameras();
  }

  Future<void> _initializeCameras() async {
    try {
      debugPrint('📷 Initializing cameras...');
      
      // Request camera permission first
      if (mounted) {
        final hasPermission = await PermissionHelper.requestCameraPermission(
          context,
        );
        
        debugPrint('📷 Camera permission granted: $hasPermission');
        
        if (!hasPermission) {
          setState(() {
            _cameraPermissionDenied = true;
            _cameraErrorMessage = 'Camera permission denied';
          });
          if (mounted) {
            _showCameraUnavailableDialog('Permission Denied', 
              'Camera permission was denied. You can continue without camera preview or grant permission in settings.');
          }
          return;
        }
      }

      cameras = await availableCameras();
      debugPrint('📷 Available cameras: ${cameras?.length ?? 0}');
      
      if (cameras != null && cameras!.isNotEmpty) {
        for (var i = 0; i < cameras!.length; i++) {
          debugPrint('📷 Camera $i: ${cameras![i].name} - ${cameras![i].lensDirection}');
        }
      }
      
      if (cameras == null || cameras!.isEmpty) {
        setState(() {
          _cameraErrorMessage = 'No camera detected';
        });
        if (mounted) {
          _showCameraUnavailableDialog('No Camera Found', 
            'No camera detected. For Android Emulator, enable webcam in emulator settings. You can continue without camera preview.');
        }
        return;
      }
      
      if (mounted) {
        _initializeCamera();
      }
    } catch (e) {
      debugPrint('❌ Error initializing cameras: $e');
      setState(() {
        _cameraErrorMessage = 'Camera error: $e';
      });
      if (mounted) {
        _showCameraUnavailableDialog('Camera Error', 
          'Camera initialization failed: $e\n\nYou can continue without camera preview.');
      }
    }
  }

  void _showCameraUnavailableDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.blue),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 12),
            const Text(
              'Note: This is a simulation test, so camera preview is optional.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Without Camera'),
          ),
          if (_cameraPermissionDenied)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                PermissionHelper.requestCameraPermission(context).then((granted) {
                  if (granted) {
                    _initializeCameras();
                  }
                });
              },
              child: const Text('Try Again'),
            ),
        ],
      ),
    );
  }

  Future<void> _initializeCamera() async {
    if (cameras == null || cameras!.isEmpty) return;

    // Prefer front camera for eye tests (better for desktop/laptop webcams)
    CameraDescription selectedCamera;
    try {
      // Try to find front camera first
      selectedCamera = cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
    } catch (e) {
      // If no front camera, use first available (desktop usually has only one)
      selectedCamera = cameras![0];
    }

    _cameraController = CameraController(
      selectedCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      debugPrint('📷 Initializing selected camera: ${selectedCamera.name}');
      await _cameraController!.initialize();
      debugPrint('✅ Camera initialized successfully');
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('❌ Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera initialization failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startTest() {
    setState(() {
      testPhase = 1;
      progress = 0;
      blinkCount = 0;
      fatigueLevel = 0;
      testDuration = 0;
    });

    // Test progression (40 seconds)
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
        _blinkTimer?.cancel();
        _durationTimer?.cancel();
        _fatigueTimer?.cancel();
        setState(() {
          testPhase = 2;
          isTestComplete = true;
        });
      }
    });

    // Simulate blink detection
    _blinkTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || testPhase != 1) {
        timer.cancel();
        return;
      }

      // Random blink detection simulation
      if ((blinkCount / (testDuration + 1)) * 60 < 20) {
        // Keep rate reasonable
        setState(() {
          blinkCount++;
        });
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

    // Calculate fatigue level
    _fatigueTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || testPhase != 1) {
        timer.cancel();
        return;
      }

      setState(() {
        fatigueLevel = (fatigueLevel + 5).clamp(0, 100);
      });
    });
  }

  int getBlinkRate() {
    if (testDuration == 0) return 0;
    return ((blinkCount / testDuration) * 60).round();
  }

  Future<void> _saveResults() async {
    if (isSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Results already saved!'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      // Capture current frame as proof image
      XFile? imageFile;
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        try {
          imageFile = await _cameraController!.takePicture();
        } catch (e) {
          debugPrint('Could not capture image: $e');
        }
      }

      // Create temporary file if no capture
      File testImage;
      if (imageFile != null) {
        testImage = File(imageFile.path);
      } else {
        // Create a dummy file for tests without camera
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/temp_blink_test.jpg';
        testImage = File(filePath);
        await testImage.writeAsBytes([]);
      }

      // Submit test to backend
      await BlinkFatigueService.submitTest(
        imageFile: testImage,
        testDuration: testDuration.toDouble(),
      );

      // Clean up temporary file
      try {
        await testImage.delete();
      } catch (_) {}

      if (mounted) {
        setState(() {
          isSaved = true;
          isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Results saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
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

  Map<String, dynamic> getFatigueStatus() {
    final blinkRate = getBlinkRate();
    if (blinkRate < 10) {
      return {
        'level': 'High',
        'color': Colors.red,
        'message': 'Significant eye strain detected',
      };
    } else if (blinkRate < 15) {
      return {
        'level': 'Moderate',
        'color': Colors.orange,
        'message': 'Mild eye fatigue detected',
      };
    } else {
      return {
        'level': 'Low',
        'color': Colors.green,
        'message': 'Normal blink rate',
      };
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _testTimer?.cancel();
    _blinkTimer?.cancel();
    _durationTimer?.cancel();
    _fatigueTimer?.cancel();
    super.dispose();
  }

  Future<bool> _showExitDialog() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Exit Test?"),
            content: const Text(
              "Are you sure you want to exit? Your progress will be lost.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Exit"),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!isTestComplete) {
          return await _showExitDialog();
        }
        return true;
      },
      child: Scaffold(
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
          leading: isTestComplete
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, color: Colors.black87),
                  onPressed: () => _showExitDialog(),
                ),
          title: const Text("Blink & Fatigue Test"),
          centerTitle: true,
        ),
        body: SafeArea(child: isTestComplete ? _buildResults() : _buildTest()),
      ),
    );
  }

  // ============ TEST UI ============
  Widget _buildTest() {
    return Stack(
      children: [
        // Camera preview or placeholder
        if (_cameraController != null && _cameraController!.value.isInitialized)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: CameraPreview(_cameraController!),
            ),
          )
        else
          Container(
            color: Colors.grey[800],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.no_photography,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Camera Preview Unavailable',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Test will continue without camera',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Center focus point
        if (testPhase == 1)
          Center(
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(64),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Look here",
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.orange[500],
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Blink counter
        if (testPhase == 1)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.visibility_off,
                    size: 20,
                    color: Colors.orange[600],
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Blinks Detected",
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      Text(
                        blinkCount.toString(),
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
            ),
          ),

        // Fatigue meter
        if (testPhase == 1)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Fatigue Level",
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 128,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fatigueLevel / 100,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation(
                          fatigueLevel < 33
                              ? Colors.green
                              : fatigueLevel < 66
                              ? Colors.yellow[700]
                              : Colors.red,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Progress bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.8), Colors.transparent],
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Progress",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "${progress.round()}%",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 10,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation(Colors.orange[600]),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Look at the centre point and blink naturally. The AI is monitoring your blink patterns.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Start button and camera controls (only on first phase)
        if (testPhase == 0)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Camera status message
                  if (_cameraErrorMessage.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        border: Border.all(color: Colors.orange),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _cameraErrorMessage,
                              style: TextStyle(color: Colors.orange[700], fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Request permission button
                  if (_cameraPermissionDenied || _cameraErrorMessage.contains('permission'))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final granted = await PermissionHelper.requestCameraPermission(context);
                          if (granted) {
                            setState(() {
                              _cameraPermissionDenied = false;
                              _cameraErrorMessage = '';
                            });
                            _initializeCameras();
                          }
                        },
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Enable Camera'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ),
                  
                  // Start test button
                  ElevatedButton.icon(
                    onPressed: _startTest,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("Start Test"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[600],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
    final fatigueStatus = getFatigueStatus();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (fatigueStatus['color'] as Color).withOpacity(0.2),
                  (fatigueStatus['color'] as Color).withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              size: 48,
              color: fatigueStatus['color'],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Test Completed!",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Your blink and fatigue test has been successfully completed. Our AI has analysed your eye patterns.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Preliminary Results:",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _resultRow(
                  "Blink Rate",
                  "${getBlinkRate()} blinks/min",
                  Colors.blue[400]!,
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.black12),
                const SizedBox(height: 12),
                _resultRow(
                  "Total Blinks",
                  blinkCount.toString(),
                  Colors.black87,
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.black12),
                const SizedBox(height: 12),
                _resultRow("Test Duration", "${testDuration}s", Colors.black87),
                const SizedBox(height: 12),
                const Divider(color: Colors.black12),
                const SizedBox(height: 12),
                _resultRow(
                  "Fatigue Level",
                  fatigueStatus['level'],
                  fatigueStatus['color'],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (fatigueStatus['color'] as Color).withOpacity(0.2),
                  (fatigueStatus['color'] as Color).withOpacity(0.1),
                ],
              ),
              border: Border.all(
                color: (fatigueStatus['color'] as Color).withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  fatigueStatus['message'],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: fatigueStatus['color'],
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Normal blink rate: 15-20 blinks per minute. Lower rates may indicate digital eye strain.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSaving ? null : _saveResults,
              style: ElevatedButton.styleFrom(
                backgroundColor: isSaved ? Colors.green[600] : Colors.blue[600],
                disabledBackgroundColor: Colors.grey[400],
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isSaving
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          "Saving...",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isSaved ? Icons.check_circle : Icons.save,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isSaved ? "Results Saved" : "Save Results",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BlinkFatigueTestPage(),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Colors.blue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "Retry Test",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () =>
                  Navigator.popUntil(context, (route) => route.isFirst),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: Colors.grey.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "Back to Home",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.withOpacity(0.7),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
