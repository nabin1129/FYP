import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/models/eye_tracking_data.dart';
import 'package:netracare/services/eye_tracking_engine.dart';
import 'package:netracare/services/eye_tracking_service.dart';
import 'package:netracare/utils/permission_helper.dart';

class EyeTrackingTestPage extends StatefulWidget {
  const EyeTrackingTestPage({super.key});

  @override
  State<EyeTrackingTestPage> createState() => _EyeTrackingTestPageState();
}

class _EyeTrackingTestPageState extends State<EyeTrackingTestPage>
    with SingleTickerProviderStateMixin {
  // -----------
  CameraController? _cameraController;
  bool _isCameraReady = false;

  // Eye tracking engine
  EyeTrackingEngine? _engine;
  bool _faceDetected = false;
  int _noFaceSeconds = 0;
  Timer? _noFaceTimer;

  // Animation -----------
  late AnimationController _animationController;

  static const int totalPhases = 5;
  static const List<String> _phaseNames = [
    'calibration',
    'horizontal',
    'vertical',
    'circular',
    'saccade',
  ];
  static const List<int> _phaseDurations = [8, 8, 8, 8, 6];

  int _currentPhase = 0;
  bool _isTestRunning = false;
  bool _isTestComplete = false;
  bool _isInitializing = true;
  String _statusMessage = 'Initializing camera...';

  // Target dot position
  Offset _targetPosition = Offset.zero;

  // Saccade phase targets
  final List<Offset> _saccadeTargets = [];
  int _saccadeIndex = 0;
  Timer? _saccadeTimer;

  // Phase timer
  Timer? _phaseTimer;
  double _phaseProgress = 0;

  // Test start time
  DateTime? _testStartTime;

  // Frames collected per phase
  final Map<String, List<EyeTrackingFrame>> _phaseFrames = {};

  // ML Kit FaceDetector
  FaceDetector? _faceDetector;

  // Results
  EyeTrackingTestResult? _result;
  bool _isSaving = false;
  int _faceDetectedFrames = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _engine = EyeTrackingEngine();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cleanup();
    _animationController.dispose();
    super.dispose();
  }

  void _cleanup() {
    _phaseTimer?.cancel();
    _saccadeTimer?.cancel();
    _noFaceTimer?.cancel();
    _engine?.dispose();
    _faceDetector?.close();
    if (_cameraController != null) {
      if (_cameraController!.value.isStreamingImages) {
        _cameraController!.stopImageStream().catchError((_) {});
      }
      _cameraController!.dispose();
    }
  }

  // CAMERA INITIALIZATION

  Future<void> _initializeCamera() async {
    try {
      if (!mounted) return;
      final hasPermission = await PermissionHelper.requestCameraPermission(
        context,
      );
      if (!hasPermission) {
        setState(() {
          _isInitializing = false;
          _statusMessage = 'Camera permission denied';
        });
        return;
      }

      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: true,
          enableContours: true,
          enableClassification: true,
          enableTracking: true,
          minFaceSize: 0.15,
          performanceMode: FaceDetectorMode.fast,
        ),
      );

      if (!mounted) return;
      setState(() {
        _isCameraReady = true;
        _isInitializing = false;
        _statusMessage = 'Camera ready. Position your face and tap Start.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _statusMessage = 'Camera unavailable. Please check permissions and try again.';
      });
    }
  }

  // TEST CONTROL

  Future<void> _startTest() async {
    if (!_isCameraReady || _cameraController == null) return;

    _engine!.reset();
    _phaseFrames.clear();
    for (final name in _phaseNames) {
      _phaseFrames[name] = [];
    }

    final screenSize = MediaQuery.of(context).size;
    _engine!.setScreenSize(screenSize);
    _targetPosition = Offset(screenSize.width / 2, screenSize.height / 2);

    setState(() {
      _isTestRunning = true;
      _currentPhase = 0;
      _isTestComplete = false;
      _result = null;
      _noFaceSeconds = 0;
      _faceDetectedFrames = 0;
    });

    _testStartTime = DateTime.now();

    if (!_cameraController!.value.isStreamingImages) {
      await _cameraController!.startImageStream(_onCameraFrame);
    }

    _noFaceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_faceDetected && _isTestRunning) {
        setState(() => _noFaceSeconds++);
      } else {
        _noFaceSeconds = 0;
      }
    });

    _startPhase();
  }

  void _startPhase() {
    if (_currentPhase >= totalPhases) {
      _finishTest();
      return;
    }

    final screenSize = MediaQuery.of(context).size;
    final phaseName = _phaseNames[_currentPhase];
    final durationSec = _phaseDurations[_currentPhase];

    setState(() {
      _phaseProgress = 0;
      _statusMessage = _getPhaseInstruction();
    });

    _setupPhaseAnimation(phaseName, screenSize, durationSec);

    int elapsed = 0;
    _phaseTimer?.cancel();
    _phaseTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      elapsed += 100;
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(
        () => _phaseProgress = (elapsed / (durationSec * 1000)).clamp(0, 1),
      );
      if (elapsed >= durationSec * 1000) {
        timer.cancel();
        _onPhaseComplete();
      }
    });
  }

  void _setupPhaseAnimation(String phase, Size screenSize, int durationSec) {
    final cx = screenSize.width / 2;
    final cy = screenSize.height / 2;
    final rangeX = screenSize.width * 0.35;
    final rangeY = screenSize.height * 0.25;

    _saccadeTimer?.cancel();
    _animationController.stop();
    _animationController.removeListener(_animListener);

    switch (phase) {
      case 'calibration':
        _targetPosition = Offset(cx, cy);
        int step = 0;
        final positions = [
          Offset(cx, cy),
          Offset(cx - rangeX, cy - rangeY),
          Offset(cx + rangeX, cy - rangeY),
          Offset(cx + rangeX, cy + rangeY),
          Offset(cx - rangeX, cy + rangeY),
          Offset(cx, cy),
        ];
        _saccadeTimer = Timer.periodic(
          Duration(milliseconds: (durationSec * 1000) ~/ positions.length),
          (_) {
            if (step < positions.length && mounted) {
              setState(() => _targetPosition = positions[step]);
              step++;
            }
          },
        );
        break;

      case 'horizontal':
        _animationController.duration = Duration(seconds: durationSec);
        _animationController.addListener(_animListener);
        _animPhaseData = _AnimPhaseData(
          cx: cx,
          cy: cy,
          rangeX: rangeX,
          rangeY: rangeY,
          type: 'horizontal',
        );
        _animationController.repeat(reverse: true);
        break;

      case 'vertical':
        _animationController.duration = Duration(seconds: durationSec);
        _animationController.addListener(_animListener);
        _animPhaseData = _AnimPhaseData(
          cx: cx,
          cy: cy,
          rangeX: rangeX,
          rangeY: rangeY,
          type: 'vertical',
        );
        _animationController.repeat(reverse: true);
        break;

      case 'circular':
        _animationController.duration = Duration(seconds: durationSec);
        _animationController.addListener(_animListener);
        _animPhaseData = _AnimPhaseData(
          cx: cx,
          cy: cy,
          rangeX: rangeX,
          rangeY: rangeY,
          type: 'circular',
        );
        _animationController.repeat();
        break;

      case 'saccade':
        final rng = math.Random();
        _saccadeTargets.clear();
        for (int i = 0; i < 10; i++) {
          _saccadeTargets.add(
            Offset(
              cx - rangeX + rng.nextDouble() * 2 * rangeX,
              cy - rangeY + rng.nextDouble() * 2 * rangeY,
            ),
          );
        }
        _saccadeIndex = 0;
        _targetPosition = _saccadeTargets[0];
        _saccadeTimer = Timer.periodic(
          Duration(
            milliseconds: (durationSec * 1000) ~/ _saccadeTargets.length,
          ),
          (_) {
            if (_saccadeIndex < _saccadeTargets.length - 1 && mounted) {
              _saccadeIndex++;
              setState(() => _targetPosition = _saccadeTargets[_saccadeIndex]);
            }
          },
        );
        break;
    }
  }

  _AnimPhaseData? _animPhaseData;

  void _animListener() {
    if (!mounted || _animPhaseData == null) return;
    final d = _animPhaseData!;
    final t = _animationController.value;
    switch (d.type) {
      case 'horizontal':
        setState(
          () => _targetPosition = Offset(
            d.cx - d.rangeX + t * 2 * d.rangeX,
            d.cy,
          ),
        );
        break;
      case 'vertical':
        setState(
          () => _targetPosition = Offset(
            d.cx,
            d.cy - d.rangeY + t * 2 * d.rangeY,
          ),
        );
        break;
      case 'circular':
        final angle = t * 2 * math.pi;
        final radius = math.min(d.rangeX, d.rangeY) * 0.8;
        setState(
          () => _targetPosition = Offset(
            d.cx + radius * math.cos(angle),
            d.cy + radius * math.sin(angle),
          ),
        );
        break;
    }
  }

  void _onPhaseComplete() {
    _animationController.stop();
    _animationController.removeListener(_animListener);
    _saccadeTimer?.cancel();

    final phaseName = _phaseNames[_currentPhase];
    final frames = _phaseFrames[phaseName] ?? [];
    if (['horizontal', 'vertical', 'circular'].contains(phaseName) &&
        frames.isNotEmpty) {
      final pursuit = _engine!.analyzePursuit(phaseName, frames);
      _engine!.sessionData.addPursuit(pursuit);
    }

    _currentPhase++;
    if (_currentPhase < totalPhases) {
      _startPhase();
    } else {
      _finishTest();
    }
  }

  void _finishTest() {
    _phaseTimer?.cancel();
    _saccadeTimer?.cancel();
    _noFaceTimer?.cancel();
    _animationController.stop();

    if (_cameraController != null &&
        _cameraController!.value.isStreamingImages) {
      _cameraController!.stopImageStream().catchError((_) {});
    }

    final duration = _testStartTime != null
        ? DateTime.now().difference(_testStartTime!).inSeconds.toDouble()
        : 0.0;
    _engine!.sessionData.testDurationSeconds = duration;

    final result = EyeTrackingTestResult.fromSession(
      _engine!.sessionData,
      _faceDetectedFrames,
    );

    setState(() {
      _isTestRunning = false;
      _isTestComplete = true;
      _result = result;
    });
  }

  // CAMERA FRAME PROCESSING

  bool _isProcessingFrame = false;
  int _frameSkip = 0;

  void _onCameraFrame(CameraImage image) {
    if (!_isTestRunning || _isProcessingFrame) return;
    _frameSkip++;
    if (_frameSkip % 2 != 0) return;
    _isProcessingFrame = true;
    _processCameraFrame(image).then((_) => _isProcessingFrame = false);
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    if (_faceDetector == null || _cameraController == null) return;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector!.processImage(inputImage);
      if (faces.isEmpty) {
        if (mounted) setState(() => _faceDetected = false);
        return;
      }

      if (mounted) setState(() => _faceDetected = true);

      final face = faces.first;
      final timestamp = _testStartTime != null
          ? DateTime.now().difference(_testStartTime!).inMilliseconds / 1000.0
          : 0.0;
      final phaseName = _currentPhase < _phaseNames.length
          ? _phaseNames[_currentPhase]
          : '';

      final frame = _engine!.recordFrame(
        face: face,
        targetPosition: _targetPosition,
        phase: phaseName,
        timestamp: timestamp,
      );

      if (frame != null) {
        _phaseFrames[phaseName]?.add(frame);
        _faceDetectedFrames++;
      }
    } catch (e) {
      debugPrint('Frame processing error: $e');
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final controller = _cameraController!;
      final rotation = InputImageRotationValue.fromRawValue(
        controller.description.sensorOrientation,
      );
      if (rotation == null) return null;

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      final allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  // BUILD

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return PopScope(
      canPop: _isTestComplete || !_isTestRunning,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _isTestRunning) {
          final nav = Navigator.of(context);
          final exit = await _showExitDialog();
          if (exit) nav.pop();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: _isTestRunning
            ? null
            : AppBar(
                backgroundColor: AppTheme.surface,
                elevation: 1,
                titleTextStyle: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: AppTheme.fontXXL,
                  fontWeight: FontWeight.w600,
                ),
                iconTheme: const IconThemeData(color: AppTheme.textPrimary),
                title: const Text('Eye Tracking Test'),
                centerTitle: true,
              ),
        body: SafeArea(
          child: _isInitializing
              ? _buildLoading()
              : _isTestComplete
              ? _buildResults()
              : _isTestRunning
              ? _buildTestRunning()
              : _buildReadyScreen(),
        ),
      ),
    );
  }

  // Loading -----------

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppTheme.primary),
          const SizedBox(height: 16),
          Text(
            _statusMessage,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyScreen() {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: _isCameraReady && _cameraController != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CameraPreview(_cameraController!),
                    ),
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.textSecondary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.face,
                              color: _faceDetected
                                  ? AppTheme.success
                                  : AppTheme.error,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _faceDetected ? 'Face Detected' : 'No Face',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: AppTheme.fontSM,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Text(
                    _statusMessage,
                    style: const TextStyle(color: AppTheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Text(
                'Position your face in the camera frame',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: AppTheme.fontLG,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Keep 30-40 cm distance and ensure good lighting.\nThe test will track your eye movements as you follow the dot.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: AppTheme.fontSM,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isCameraReady ? _startTest : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text(
                    'Start Test',
                    style: TextStyle(
                      fontSize: AppTheme.fontLG,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  // Test Running

  Widget _buildTestRunning() {
    return Stack(
      children: [
        Container(color: const Color(0xFF1A1A2E)),

        // Target dot
        Positioned(
          left: _targetPosition.dx - 14,
          top: _targetPosition.dy - 14,
          child: _buildDot(),
        ),

        // Camera preview thumbnail
        if (_isCameraReady && _cameraController != null)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              width: 100,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _faceDetected ? AppTheme.success : AppTheme.error,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),

        // Face indicator
        Positioned(
          top: 12,
          right: 120,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _faceDetected ? AppTheme.success : AppTheme.error,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_faceDetected ? AppTheme.success : AppTheme.error)
                      .withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),

        // Phase info
        Positioned(
          top: 12,
          left: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Phase ${_currentPhase + 1}/$totalPhases',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppTheme.fontSM,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 100,
                child: LinearProgressIndicator(
                  value: _phaseProgress,
                  backgroundColor: AppTheme.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Instruction
        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                _getPhaseInstruction(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppTheme.fontBody,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Follow the dot with your eyes',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: AppTheme.fontSM,
                ),
              ),
            ],
          ),
        ),

        // No face warning
        if (_noFaceSeconds >= 3)
          Positioned(
            top: 60,
            left: 40,
            right: 40,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Face not detected. Position your face in the camera.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppTheme.fontSM,
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

  Widget _buildDot() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.6),
            blurRadius: 16,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  String _getPhaseInstruction() {
    if (_currentPhase >= _phaseNames.length) return '';
    switch (_phaseNames[_currentPhase]) {
      case 'calibration':
        return 'Calibration â€” Focus on each dot position';
      case 'horizontal':
        return 'Horizontal Pursuit â€” Track left to right';
      case 'vertical':
        return 'Vertical Pursuit â€” Track up and down';
      case 'circular':
        return 'Circular Pursuit â€” Follow the circular path';
      case 'saccade':
        return 'Saccade Test â€” Look at the jumping dot quickly';
      default:
        return '';
    }
  }

  // RESULTS

  Widget _buildResults() {
    final r = _result!;
    final color = _getClassificationColor(r.classification);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 56,
              color: AppTheme.success,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Test Complete',
            style: TextStyle(
              fontSize: AppTheme.fontHeading,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          _buildScoreCard(r, color),
          const SizedBox(height: 20),
          _buildMetricsCard(r),
          const SizedBox(height: 20),
          _buildBlinkCard(r),
          const SizedBox(height: 20),
          if (r.pursuits.isNotEmpty) ...[
            _buildPursuitCard(r),
            const SizedBox(height: 20),
          ],
          _buildActionButtons(r),
        ],
      ),
    );
  }

  Widget _buildScoreCard(EyeTrackingTestResult r, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          const Text(
            'Overall Score',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: AppTheme.fontSM,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${r.overallScore.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              r.classification,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCard(EyeTrackingTestResult r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Eye Movement Metrics',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: AppTheme.fontBody,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _metricRow(
            'Gaze Accuracy',
            '${r.gazeAccuracy.toStringAsFixed(1)}%',
            AppTheme.info,
          ),
          _divider(),
          _metricRow(
            'Fixation Stability',
            '${r.fixationStability.toStringAsFixed(1)}%',
            AppTheme.primary,
          ),
          _divider(),
          _metricRow(
            'Saccade Consistency',
            '${r.saccadeConsistency.toStringAsFixed(1)}%',
            AppTheme.success,
          ),
          _divider(),
          _metricRow(
            'Pursuit Smoothness',
            '${r.pursuitSmoothness.toStringAsFixed(1)}%',
            AppTheme.warning,
          ),
          _divider(),
          _metricRow('Data Points', '${r.totalDataPoints}', AppTheme.info),
          _divider(),
          _metricRow(
            'Face Detected Frames',
            '${r.faceDetectedFrames}',
            AppTheme.success,
          ),
          _divider(),
          _metricRow('Saccades Detected', '${r.saccadeCount}', AppTheme.info),
          _divider(),
          _metricRow(
            'Test Duration',
            '${r.testDurationSeconds.toStringAsFixed(0)}s',
            AppTheme.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildBlinkCard(EyeTrackingTestResult r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Blink & EAR Analysis',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: AppTheme.fontBody,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _metricRow('Blink Count', '${r.blinkCount}', AppTheme.info),
          _divider(),
          _metricRow(
            'Blink Rate',
            '${r.blinkRate.toStringAsFixed(1)} blinks/min',
            AppTheme.primary,
          ),
          _divider(),
          _metricRow(
            'Mean EAR',
            r.earStats['mean']?.toStringAsFixed(3) ?? 'N/A',
            AppTheme.success,
          ),
          _divider(),
          _metricRow(
            'Min EAR',
            r.earStats['min']?.toStringAsFixed(3) ?? 'N/A',
            AppTheme.warning,
          ),
          _divider(),
          _metricRow('Microsaccades', '${r.microsaccadeCount}', AppTheme.info),
        ],
      ),
    );
  }

  Widget _buildPursuitCard(EyeTrackingTestResult r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Smooth Pursuit Breakdown',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: AppTheme.fontBody,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < r.pursuits.length; i++) ...[
            if (i > 0) _divider(),
            _metricRow(
              '${r.pursuits[i].direction[0].toUpperCase()}${r.pursuits[i].direction.substring(1)}',
              'Acc: ${r.pursuits[i].accuracy.toStringAsFixed(0)}% | Smooth: ${(r.pursuits[i].smoothness * 100).toStringAsFixed(0)}%',
              AppTheme.primary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(EyeTrackingTestResult r) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : () => _saveResults(r),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Save Results',
                    style: TextStyle(
                      fontSize: AppTheme.fontLG,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _retryTest,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppTheme.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Retry Test',
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
                Navigator.of(context).popUntil((route) => route.isFirst),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(
                color: AppTheme.textLight.withValues(alpha: 0.5),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Back to Home',
              style: TextStyle(
                fontSize: AppTheme.fontLG,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: AppTheme.fontBody,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: AppTheme.fontBody,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Divider(color: AppTheme.textLight.withValues(alpha: 0.2), height: 1);

  Color _getClassificationColor(String classification) {
    switch (classification) {
      case 'Excellent':
        return AppTheme.success;
      case 'Good':
        return AppTheme.info;
      case 'Fair':
        return AppTheme.warning;
      case 'Poor':
        return AppTheme.error;
      default:
        return AppTheme.textLight;
    }
  }

  // SAVE / RETRY

  Future<void> _saveResults(EyeTrackingTestResult r) async {
    setState(() => _isSaving = true);

    try {
      final dataPoints = _engine!.sessionData.frames
          .map((f) => f.toJson())
          .toList();

      await EyeTrackingService.uploadTestData(
        EyeTrackingTestData(
          dataPoints: dataPoints,
          testName: 'Eye Tracking Test',
          screenWidth: _engine!.sessionData.screenWidth,
          screenHeight: _engine!.sessionData.screenHeight,
          testDuration: r.testDurationSeconds,
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Results saved successfully!'),
          backgroundColor: AppTheme.success,
          duration: Duration(seconds: 2),
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    } catch (e) {
      if (!mounted) return;

      // Fallback: save pre-computed results directly
      try {
        await EyeTrackingService.saveTestResults(
          EyeTrackingResult(
            gazeAccuracy: r.gazeAccuracy,
            dataPointsCollected: r.totalDataPoints,
            successfulTracking: r.faceDetectedFrames,
            testDuration: r.testDurationSeconds.toInt(),
            classification: r.classification,
            rawData: r.toApiJson()['raw_data'] as Map<String, dynamic>,
          ),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Results saved!'),
            backgroundColor: AppTheme.success,
          ),
        );
      } catch (e2) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e2'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _retryTest() {
    _engine?.reset();
    setState(() {
      _currentPhase = 0;
      _isTestComplete = false;
      _isTestRunning = false;
      _result = null;
      _statusMessage = 'Ready. Tap Start to begin.';
    });
  }

  Future<bool> _showExitDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Text(
              'Exit Test?',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            content: const Text(
              'Your progress will not be saved.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: AppTheme.fontLG,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Continue'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Exit',
                  style: TextStyle(color: AppTheme.error),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }
}

/// Helper class for animation phase data
class _AnimPhaseData {
  final double cx, cy, rangeX, rangeY;
  final String type;
  const _AnimPhaseData({
    required this.cx,
    required this.cy,
    required this.rangeX,
    required this.rangeY,
    required this.type,
  });
}
