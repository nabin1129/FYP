import 'package:flutter/material.dart';
import '../../services/camera_service.dart';
import '../../services/ml_service.dart';
import '../../models/test_models.dart';
import '../../widgets/test/camera_preview_widget.dart';
import '../../config/app_theme.dart';

/// Camera Test Page
///
/// Provides camera-based testing interface for all eye tests.
/// Captures image and processes through ML models.
class CameraTestPage extends StatefulWidget {
  final TestType testType;

  const CameraTestPage({
    super.key,
    required this.testType,
  });

  @override
  State<CameraTestPage> createState() => _CameraTestPageState();
}

class _CameraTestPageState extends State<CameraTestPage> {
  final CameraService _cameraService = CameraService();
  final MLService _mlService = MLService();

  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _cameraService.initialize();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to initialize camera: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _captureAndProcess() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Capture image from camera
      final String imagePath = await _cameraService.captureImage();

      // Show brief feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Image captured! Processing...'),
              ],
            ),
            backgroundColor: AppTheme.success,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Process with appropriate ML model based on test type
      TestResult result;

      switch (widget.testType) {
        case TestType.visualAcuity:
          result = await _mlService.analyzeVisualAcuity(imagePath);
          break;
        case TestType.colorBlindness:
          result = await _mlService.analyzeColorBlindness(imagePath);
          break;
        case TestType.astigmatism:
          result = await _mlService.analyzeAstigmatism(imagePath);
          break;
        case TestType.contrastSensitivity:
          result = await _mlService.analyzeContrastSensitivity(imagePath);
          break;
        case TestType.eyeTracking:
          result = await _mlService.analyzeEyeTracking(imagePath);
          break;
        case TestType.pupilResponse:
          result = await _mlService.analyzePupilResponse(imagePath);
          break;
        case TestType.fatigue:
          result = await _mlService.analyzeFatigue(imagePath);
          break;
      }

      // Navigate back with result
      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Processing failed: ${e.toString()}';
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  String _getInstructions() {
    switch (widget.testType) {
      case TestType.visualAcuity:
        return 'Position your eye 30cm from the camera. Look directly at the lens with one eye at a time.';
      case TestType.colorBlindness:
        return 'Ensure good lighting. Look at the camera with both eyes open and steady.';
      case TestType.astigmatism:
        return 'Focus on the camera lens. Blink naturally and look straight ahead.';
      case TestType.contrastSensitivity:
        return 'Ensure even lighting. Look directly at the camera without squinting.';
      case TestType.eyeTracking:
        return 'Keep your head still. Your eye movements will be tracked automatically.';
      case TestType.pupilResponse:
        return 'Look at the camera. The test will measure your pupil response to light changes.';
      case TestType.fatigue:
        return 'Relax and look naturally at the camera. Blink at your normal rate.';
    }
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.testType.displayName),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppTheme.spacingMD),
            Text(
              'Initializing camera...',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textLight,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLG),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.error,
              ),
              const SizedBox(height: AppTheme.spacingMD),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.error,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: AppTheme.spacingLG),
              ElevatedButton.icon(
                onPressed: _initializeCamera,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingLG,
                    vertical: AppTheme.spacingMD,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        CameraPreviewWidget(
          cameraService: _cameraService,
          onCapture: _captureAndProcess,
          instructions: _getInstructions(),
        ),
        
        // Processing Overlay
        if (_isProcessing)
          Container(
            color: Colors.black87,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                  SizedBox(height: AppTheme.spacingLG),
                  Text(
                    'Processing image...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingSM),
                  Text(
                    'This may take a few seconds',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
