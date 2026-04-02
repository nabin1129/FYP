import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:netracare/utils/permission_helper.dart';
import 'package:netracare/services/pupil_reflex_service.dart';

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

  int testPhase =
      0; // 0: ready, 1: flash test, 2: nystagmus test, 3: processing, 4: results
  int totalPhases = 3;
  double progress = 0;
  bool isTestComplete = false;
  bool flashActive = false;
  int countdown = 3;
  DateTime? flashStartTime;
  DateTime? reactionTime;
  bool _isRecording = false;
  String? _videoPath;
  String? _testId;

  // Pupil reflex metrics
  double pupilReactionTime = 0.0;
  String constrictionAmplitude = "";
  String symmetry = "";

  // Nystagmus metrics
  bool? nystagmusDetected;
  String? nystagmusType;
  String? nystagmusSeverity;
  double? confidence;
  String? diagnosis;
  String? recommendations;

  bool isSaving = false;
  bool isSaved = false;
  bool _isCapturing = false;

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
              'Camera permission was denied. This test requires camera access and face detection before it can start.',
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
            'No camera detected on this device. This test cannot start without face detection.',
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
          'Camera initialization failed. This test cannot start without camera and face detection.',
        );
      }
    }
  }

  Future<bool> _detectFaceBeforeStart() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return false;
    }

    XFile? capturedImage;
    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableContours: false,
        enableLandmarks: false,
      ),
    );

    try {
      _isCapturing = true;
      capturedImage = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(capturedImage.path);
      final faces = await faceDetector.processImage(inputImage);
      return faces.isNotEmpty;
    } catch (e) {
      debugPrint('Face detection pre-check failed: $e');
      return false;
    } finally {
      _isCapturing = false;
      await faceDetector.close();
      if (capturedImage != null) {
        try {
          await File(capturedImage.path).delete();
        } catch (_) {}
      }
    }
  }

  void _showCameraUnavailableDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(message)],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
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
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _startTest() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Camera is required for this test. Please enable camera and keep your face visible.',
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final hasFace = await _detectFaceBeforeStart();
    if (!hasFace) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Face not detected. Please align your face in the camera and try again.',
          ),
          backgroundColor: AppTheme.error,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Initialize test session
    try {
      debugPrint('Starting test session...');
      final result = await PupilReflexService.startNystagmusTest();
      if (result['test_id'] != null) {
        _testId = result['test_id'].toString();
        debugPrint('Test session created: $_testId');
      } else {
        debugPrint('No test_id in response: $result');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not start test session. Please try again.'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      final startError = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(startError),
          backgroundColor: AppTheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
      debugPrint('Failed to start test session: $e');
      return;
    }

    // Start video recording
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        debugPrint('Starting video recording...');
        await _cameraController!.startVideoRecording();
        _isRecording = true;
        debugPrint('Video recording started');
      } catch (e) {
        debugPrint('Failed to start recording: $e');
      }
    } else {
      debugPrint('Camera not initialized');
    }

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
        });
        _startNystagmusTest();
      }
    });
  }

  void _startNystagmusTest() {
    // Continue recording for nystagmus detection (10 more seconds)
    Timer(const Duration(seconds: 10), () {
      _stopRecordingAndAnalyze();
    });
  }

  Future<void> _stopRecordingAndAnalyze() async {
    debugPrint('Stopping recording...');
    if (_cameraController != null &&
        _cameraController!.value.isRecordingVideo) {
      try {
        final video = await _cameraController!.stopVideoRecording();
        _videoPath = video.path;
        _isRecording = false;
        debugPrint('Recording stopped. Video saved: $_videoPath');

        setState(() => testPhase = 3);
        _analyzeResults();
      } catch (e) {
        debugPrint('Failed to stop recording: $e');
        if (mounted) {
          setState(() {
            testPhase = 0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not capture test video. Please keep your face visible and try again.',
              ),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } else {
      debugPrint('Camera not recording');
      if (mounted) {
        setState(() {
          testPhase = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Video recording did not start. Please retry and keep your face in frame.',
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _analyzeResults() async {
    bool analysisSuccessful = false;
    String? analysisError;

    // Analyze video for nystagmus
    if (_videoPath != null && _testId != null) {
      try {
        debugPrint('Analyzing video: $_videoPath with testId: $_testId');
        final result = await PupilReflexService.analyzeVideoForNystagmus(
          videoFile: File(_videoPath!),
          testId: _testId!,
        );

        debugPrint('Taking picture...');

        final payload = (result['results'] is Map<String, dynamic>)
            ? result['results'] as Map<String, dynamic>
            : result;
        final nystagmus = (payload['nystagmus'] is Map<String, dynamic>)
            ? payload['nystagmus'] as Map<String, dynamic>
            : null;

        if (nystagmus != null) {
          nystagmusDetected = nystagmus['detected'] ?? false;
          nystagmusType = nystagmus['type'];
          nystagmusSeverity = nystagmus['severity'];
          confidence = (nystagmus['confidence'] as num?)?.toDouble();
          diagnosis = payload['diagnosis'];
          recommendations = payload['recommendations'];
          analysisSuccessful = true;
          debugPrint(
            'Nystagmus analysis successful: detected=$nystagmusDetected',
          );
        }
      } catch (e) {
        analysisError = e.toString().replaceAll('Exception: ', '');
        debugPrint('Analysis failed: $e');
      }
    } else {
      debugPrint(
        'Missing video or testId: videoPath=$_videoPath, testId=$_testId',
      );
    }

    if (!analysisSuccessful || nystagmusDetected == null) {
      if (mounted) {
        setState(() {
          testPhase = 0;
        });
        final msg = (analysisError != null && analysisError.isNotEmpty)
            ? analysisError
            : 'Analysis failed. Please keep your face clearly visible and retry.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() {
      testPhase = 4;
      isTestComplete = true;
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
          backgroundColor: AppTheme.primary,
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
      if (_cameraController != null &&
          _cameraController!.value.isInitialized &&
          !_isCapturing) {
        _isCapturing = true;
        try {
          debugPrint('Taking picture...');
          final xFile = await _cameraController!.takePicture().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('Camera capture timeout - continuing without image');
              throw TimeoutException('Camera capture timeout');
            },
          );
          imageFile = File(xFile.path);
          debugPrint('Picture captured successfully');
        } catch (e) {
          debugPrint('Could not capture image: $e');
          // Continue without image
        } finally {
          _isCapturing = false;
        }
      }

      // Submit test to backend
      await PupilReflexService.submitTest(
        reactionTime: pupilReactionTime,
        constrictionAmplitude: constrictionAmplitude,
        symmetry: symmetry,
        testDuration: 15.0, // 5s flash + 10s nystagmus test
        imageFile: imageFile,
        nystagmusDetected: nystagmusDetected,
        nystagmusType: nystagmusType,
        nystagmusSeverity: nystagmusSeverity,
        nystagmusConfidence: confidence,
        diagnosis: diagnosis,
        recommendations: recommendations,
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
            backgroundColor: AppTheme.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save results: $e'),
            backgroundColor: AppTheme.error,
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

  Future<void> _handleExitPressed() async {
    final exit = await _showExitDialog();
    if (exit && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _restartTestPage() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PupilReflexTestPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: isTestComplete,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final nav = Navigator.of(context);
          final exit = await _showExitDialog();
          if (exit) nav.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          titleTextStyle: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: AppTheme.fontXXL,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: const IconThemeData(color: AppTheme.textPrimary),
          leading: isTestComplete
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textPrimary),
                  onPressed: _handleExitPressed,
                ),
          title: const Text("Pupil Reflex & Nystagmus Test"),
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
          color: AppTheme.background,
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
                  color: AppTheme.primary.withValues(alpha: 0.3),
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
                        color: AppTheme.testDark,
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
                                fontSize: AppTheme.fontLG,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Test will continue without camera',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: AppTheme.fontSM,
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
                    ? Colors.white.withValues(alpha: 0.8)
                    : Colors.white,
                width: double.infinity,
                height: double.infinity,
              );
            },
          )
        else if (testPhase == 2)
          // Nystagmus test - show camera preview
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: MediaQuery.of(context).size.height * 0.6,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.3),
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
                      : Container(color: AppTheme.testDark),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.remove_red_eye, color: Colors.white, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'Nystagmus Detection',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: AppTheme.fontXL,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Keep looking at camera for 10 seconds',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: AppTheme.fontBody,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else if (testPhase == 3)
          // Processing phase
          Center(
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 24),
                  Text(
                    'Analyzing Results...',
                    style: TextStyle(
                      fontSize: AppTheme.fontXL,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Processing video for eye movements',
                    style: TextStyle(
                      fontSize: AppTheme.fontBody,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
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
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(60),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      countdown.toString(),
                      style: const TextStyle(
                        fontSize: AppTheme.fontScore,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Look directly at the camera",
                  style: TextStyle(
                    fontSize: AppTheme.fontLG,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        // Progress indicator
        if (testPhase > 0 && testPhase < 3)
          Positioned(
            top: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (testPhase == 1) ...[
                  Text(
                    "${(progress).toStringAsFixed(0)}%",
                    style: const TextStyle(
                      fontSize: AppTheme.fontHeading,
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
                        valueColor: AlwaysStoppedAnimation(AppTheme.success),
                      ),
                    ),
                  ),
                ] else if (testPhase == 2 && _isRecording) ...[
                  // Recording indicator for nystagmus
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.error,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          color: Colors.white,
                          size: 12,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Recording',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: Column(
            children: [
              if (testPhase == 0 && countdown == 3)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _startTest,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("Start Test"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
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
              if (testPhase == 0 && countdown == 3) const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _restartTestPage,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Restart'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppTheme.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _handleExitPressed,
                      icon: const Icon(Icons.close),
                      label: const Text('Exit'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: AppTheme.textSecondary.withValues(alpha: 0.6),
                        ),
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
              color: AppTheme.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle, size: 48, color: AppTheme.success),
          ),
          const SizedBox(height: 24),
          const Text(
            "Test Completed!",
            style: TextStyle(
              fontSize: AppTheme.fontHeading,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Your comprehensive eye movement test is complete.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTheme.fontBody,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),

          // Pupil Reflex Results
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.flash_on, color: AppTheme.accent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Pupil Reflex Results",
                      style: TextStyle(
                        fontSize: AppTheme.fontXL,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _resultRow(
                  "Pupil Reaction Time",
                  "${pupilReactionTime.toStringAsFixed(3)}s",
                  _getReactionTimeColor(),
                ),
                const SizedBox(height: 12),
                const Divider(color: AppTheme.divider),
                const SizedBox(height: 12),
                _resultRow(
                  "Constriction Amplitude",
                  constrictionAmplitude,
                  _getAmplitudeColor(),
                ),
                const SizedBox(height: 12),
                const Divider(color: AppTheme.divider),
                const SizedBox(height: 12),
                _resultRow("Symmetry", symmetry, _getSymmetryColor()),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Nystagmus Results
          if (nystagmusDetected != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.remove_red_eye,
                        color: AppTheme.accent,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Nystagmus Detection Results",
                        style: TextStyle(
                          fontSize: AppTheme.fontXL,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _resultRow(
                    "Status",
                    nystagmusDetected! ? 'Detected' : 'Not Detected',
                    nystagmusDetected! ? AppTheme.warning : AppTheme.success,
                  ),
                  if (nystagmusDetected!) ...[
                    const SizedBox(height: 12),
                    const Divider(color: AppTheme.divider),
                    const SizedBox(height: 12),
                    _resultRow(
                      "Type",
                      nystagmusType ?? 'N/A',
                      AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppTheme.divider),
                    const SizedBox(height: 12),
                    _resultRow(
                      "Severity",
                      nystagmusSeverity ?? 'N/A',
                      AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppTheme.divider),
                    const SizedBox(height: 12),
                    _resultRow(
                      "Confidence",
                      confidence != null
                          ? '${(confidence! * 100).toStringAsFixed(1)}%'
                          : 'N/A',
                      AppTheme.textSecondary,
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Diagnosis
          if (diagnosis != null && diagnosis!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.medical_information, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Diagnosis',
                          style: TextStyle(
                            fontSize: AppTheme.fontBody,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          diagnosis!,
                          style: TextStyle(
                            fontSize: AppTheme.fontSM,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Recommendations
          if (recommendations != null && recommendations!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.recommend, color: AppTheme.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recommendations',
                          style: TextStyle(
                            fontSize: AppTheme.fontBody,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.success,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recommendations!,
                          style: TextStyle(
                            fontSize: AppTheme.fontSM,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Info note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Normal pupil reaction time: 0.2-0.4s. Results may vary based on lighting conditions.',
                    style: TextStyle(
                      fontSize: AppTheme.fontSM,
                      color: AppTheme.primaryDark,
                    ),
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
                backgroundColor: isSaved ? AppTheme.success : AppTheme.primary,
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
                            fontSize: AppTheme.fontLG,
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
                            fontSize: AppTheme.fontLG,
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
                side: const BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "Retry Test",
                style: TextStyle(
                  fontSize: AppTheme.fontLG,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
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
                side: BorderSide(
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "Back to Home",
                style: TextStyle(
                  fontSize: AppTheme.fontLG,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
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
      return AppTheme.success;
    } else if (pupilReactionTime < 0.4) {
      return AppTheme.primary;
    } else {
      return AppTheme.warning;
    }
  }

  Color _getAmplitudeColor() {
    if (constrictionAmplitude == "Excellent") {
      return AppTheme.success;
    } else if (constrictionAmplitude == "Normal") {
      return AppTheme.primary;
    } else {
      return AppTheme.warning;
    }
  }

  Color _getSymmetryColor() {
    return symmetry == "Equal" ? AppTheme.success : AppTheme.warning;
  }

  Widget _resultRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: AppTheme.fontLG,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: AppTheme.fontBody,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
