import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../utils/permission_helper.dart';
import '../services/pupil_reflex_service.dart';

class PupilReflexTestPage extends StatefulWidget {
  const PupilReflexTestPage({super.key});

  @override
  State<PupilReflexTestPage> createState() => _PupilReflexTestPageState();
}

class _PupilReflexTestPageState extends State<PupilReflexTestPage>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? cameras;
  late AnimationController _flashAnimationController;

  int testPhase = 0; // 0: ready, 1: flash test, 2: results
  int totalPhases = 2;
  double progress = 0;
  bool isTestComplete = false;
  bool flashActive = false;
  int countdown = 3;
  DateTime? flashStartTime;
  DateTime? reactionTime;

  // Test metrics
  double pupilReactionTime = 0.0;
  String constrictionAmplitude = "";
  String symmetry = "";
  bool isSaving = false;
  bool isSaved = false;

  @override
  void initState() {
    super.initState();
    _flashAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
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
            _showCameraUnavailableDialog(
              'Permission Denied',
              'Camera permission was denied. You can continue without camera preview.',
            );
          }
          return;
        }
      }

      cameras = await availableCameras();
      if (cameras == null || cameras!.isEmpty) {
        if (mounted) {
          _showCameraUnavailableDialog(
            'No Camera Found',
            'No camera detected on this device. You can continue without camera preview.',
          );
        }
        return;
      }

      if (mounted) {
        _initializeCamera();
      }
    } catch (e) {
      debugPrint('Error initializing cameras: $e');
      if (mounted) {
        _showCameraUnavailableDialog(
          'Camera Error',
          'Camera initialization failed. You can continue without camera preview.',
        );
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
      debugPrint('Error initializing camera: $e');
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
    _startCountdown();
  }

  void _startCountdown() {
    countdown = 3;
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        countdown--;
      });

      if (countdown <= 0) {
        timer.cancel();
        setState(() {
          testPhase = 1;
        });
        _startFlashTest();
      }
    });
  }

  void _startFlashTest() {
    setState(() {
      flashActive = true;
      progress = 0;
      flashStartTime = DateTime.now();
    });

    _flashAnimationController.repeat(reverse: true);

    // Simulate reaction after random time (200-500ms)
    final random = Random();
    final reactionDelay = 200 + random.nextInt(300);

    Timer(Duration(milliseconds: reactionDelay), () {
      if (mounted) {
        setState(() {
          reactionTime = DateTime.now();
        });
      }
    });

    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        progress += 10;
      });

      if (progress >= 100) {
        timer.cancel();
        _flashAnimationController.stop();
        _calculateResults();
        setState(() {
          flashActive = false;
          testPhase = 2;
          isTestComplete = true;
        });
      }
    });
  }

  void _calculateResults() {
    final random = Random();

    // Calculate reaction time (0.2 - 0.5 seconds)
    if (reactionTime != null && flashStartTime != null) {
      pupilReactionTime =
          reactionTime!.difference(flashStartTime!).inMilliseconds / 1000.0;
    } else {
      pupilReactionTime = 0.2 + (random.nextDouble() * 0.3);
    }

    // Determine constriction amplitude based on reaction time
    if (pupilReactionTime < 0.3) {
      constrictionAmplitude = "Normal";
    } else if (pupilReactionTime < 0.4) {
      constrictionAmplitude = "Normal";
    } else {
      constrictionAmplitude = "Weak";
    }

    // Randomize symmetry (90% equal, 10% slightly unequal)
    symmetry = random.nextDouble() > 0.1 ? "Equal" : "Unequal";
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
      // Capture current frame as proof image (optional)
      File? imageFile;
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        try {
          debugPrint('📸 Taking picture...');
          final xFile = await _cameraController!.takePicture().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint(
                '⏱️ Camera capture timeout - continuing without image',
              );
              throw TimeoutException('Camera capture timeout');
            },
          );
          imageFile = File(xFile.path);
          debugPrint('✅ Picture captured successfully');
        } catch (e) {
          debugPrint('⚠️ Could not capture image: $e');
          // Continue without image
        }
      }

      // Submit test to backend
      await PupilReflexService.submitTest(
        reactionTime: pupilReactionTime,
        constrictionAmplitude: constrictionAmplitude,
        symmetry: symmetry,
        testDuration: 10.0, // Approximate test duration
        imageFile: imageFile,
      );

      // Clean up image file
      if (imageFile != null) {
        try {
          await imageFile.delete();
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          isSaved = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Results saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save results: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _flashAnimationController.dispose();
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
          title: const Text("Pupil Reflex Test"),
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
        // Background
        Container(
          color: const Color(0xFFF5F7FA),
          width: double.infinity,
          height: double.infinity,
        ),

        // Camera preview
        if (testPhase == 0)
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  _cameraController != null &&
                      _cameraController!.value.isInitialized
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CameraPreview(_cameraController!),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(10),
                      ),
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
            ),
          )
        else if (testPhase == 1)
          AnimatedBuilder(
            animation: _flashAnimationController,
            builder: (context, child) {
              return Container(
                color: _flashAnimationController.value > 0.5
                    ? Colors.white.withOpacity(0.8)
                    : Colors.white,
                width: double.infinity,
                height: double.infinity,
              );
            },
          ),

        // Countdown/Flash indicator
        if (testPhase == 0)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(60),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      countdown.toString(),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Look directly at the camera",
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        // Progress indicator
        Positioned(
          top: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${(progress).toStringAsFixed(0)}%",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    backgroundColor: Colors.white30,
                    valueColor: AlwaysStoppedAnimation(Colors.green[400]),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Start button (only on first phase)
        if (testPhase == 0 && countdown == 3)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _startTest,
                icon: const Icon(Icons.play_arrow),
                label: const Text("Start Test"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ============ RESULTS UI ============
  Widget _buildResults() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle, size: 48, color: Colors.green[400]),
          ),
          const SizedBox(height: 24),
          const Text(
            "Test Completed!",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Your pupil reflex test has been successfully completed.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          Container(
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
                  "Test Results:",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                _resultRow(
                  "Pupil Reaction Time",
                  "${pupilReactionTime.toStringAsFixed(3)}s",
                  _getReactionTimeColor(),
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.black12),
                const SizedBox(height: 12),
                _resultRow(
                  "Constriction Amplitude",
                  constrictionAmplitude,
                  _getAmplitudeColor(),
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.black12),
                const SizedBox(height: 12),
                _resultRow("Symmetry", symmetry, _getSymmetryColor()),
              ],
            ),
          ),
          const SizedBox(height: 24),
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
                    'Normal pupil reaction time: 0.2-0.4s. Results may vary based on lighting conditions.',
                    style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                  ),
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
                    builder: (_) => const PupilReflexTestPage(),
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

  Color _getReactionTimeColor() {
    if (pupilReactionTime < 0.3) {
      return Colors.green[600]!;
    } else if (pupilReactionTime < 0.4) {
      return Colors.blue[600]!;
    } else {
      return Colors.orange[600]!;
    }
  }

  Color _getAmplitudeColor() {
    if (constrictionAmplitude == "Excellent") {
      return Colors.green[600]!;
    } else if (constrictionAmplitude == "Normal") {
      return Colors.blue[600]!;
    } else {
      return Colors.orange[600]!;
    }
  }

  Color _getSymmetryColor() {
    return symmetry == "Equal" ? Colors.green[600]! : Colors.orange[600]!;
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
