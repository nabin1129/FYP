/// Distance Monitor Widget
/// Wrapper widget that adds real-time distance enforcement to test screens
/// Author: NetraCare Team
/// Date: January 26, 2026

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../models/distance_calibration_model.dart';
import '../services/distance_detection_service.dart';
import '../services/camera_manager_service.dart';
import 'distance_feedback_overlay.dart';
import 'face_alignment_guide.dart';

/// Composable widget that wraps test content with distance monitoring
class DistanceMonitorWidget extends StatefulWidget {
  /// Child widget (test content)
  final Widget child;

  /// Calibration data
  final DistanceCalibrationData calibrationData;

  /// Show camera preview?
  final bool showCameraPreview;

  /// Show face alignment guide?
  final bool showFaceGuide;

  /// Show distance feedback overlay?
  final bool showFeedbackOverlay;

  /// Overlay position
  final OverlayPosition overlayPosition;

  /// Callback when test should be paused (distance invalid)
  final VoidCallback? onTestPaused;

  /// Callback when test can resume (distance valid)
  final VoidCallback? onTestResumed;

  /// Callback for distance validation updates
  final Function(DistanceValidationResult)? onDistanceUpdate;

  /// Enable continuous monitoring? (vs. calibration-only)
  final bool continuousMonitoring;

  const DistanceMonitorWidget({
    super.key,
    required this.child,
    required this.calibrationData,
    this.showCameraPreview = false,
    this.showFaceGuide = true,
    this.showFeedbackOverlay = true,
    this.overlayPosition = OverlayPosition.top,
    this.onTestPaused,
    this.onTestResumed,
    this.onDistanceUpdate,
    this.continuousMonitoring = true,
  });

  @override
  State<DistanceMonitorWidget> createState() => _DistanceMonitorWidgetState();
}

class _DistanceMonitorWidgetState extends State<DistanceMonitorWidget> {
  final DistanceDetectionService _distanceService = DistanceDetectionService();
  final CameraManagerService _cameraManager = CameraManagerService();

  DistanceValidationResult? _currentResult;
  bool _isTestPaused = false;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeMonitoring();
  }

  Future<void> _initializeMonitoring() async {
    try {
      // Add timeout to prevent indefinite waiting
      await Future.any([
        _performInitialization(),
        Future.delayed(const Duration(seconds: 5), () {
          throw TimeoutException(
            'Initialization timeout - proceeding without distance monitoring',
          );
        }),
      ]);

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      // Instead of blocking, just show the content without monitoring
      debugPrint('Distance monitoring initialization failed: $e');
      debugPrint('Proceeding without distance monitoring...');
      setState(() {
        _isInitialized = true; // Allow test to proceed
        _errorMessage = null; // Don't show error, just skip monitoring
      });
    }
  }

  Future<void> _performInitialization() async {
    // Initialize camera
    await _cameraManager.initialize(
      useFrontCamera: true,
      resolution: ResolutionPreset.high,
    );

    // Initialize distance detection
    await _distanceService.initialize();

    // Set calibration
    _distanceService.setCalibration(widget.calibrationData);

    if (widget.continuousMonitoring) {
      // Start continuous monitoring
      await _distanceService.startDetection();

      // Listen to distance updates
      _distanceService.distanceStream.listen((result) {
        setState(() {
          _currentResult = result;
        });

        // Handle test pause/resume
        if (result.status.shouldPauseTest && !_isTestPaused) {
          _isTestPaused = true;
          widget.onTestPaused?.call();
        } else if (!result.status.shouldPauseTest && _isTestPaused) {
          _isTestPaused = false;
          widget.onTestResumed?.call();
        }

        // Notify parent
        widget.onDistanceUpdate?.call(result);
      });
    }
  }

  @override
  void dispose() {
    _distanceService.stopDetection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading only during initial setup
    if (!_isInitialized) {
      return _buildLoadingView();
    }

    // If there was an error but we've marked as initialized, just show the child
    // (distance monitoring will be disabled but test can proceed)
    if (_errorMessage != null) {
      return widget.child; // Show test without monitoring
    }

    return Stack(
      children: [
        // Camera preview (background)
        if (widget.showCameraPreview) _buildCameraPreview(),

        // Test content
        widget.child,

        // Face alignment guide
        if (widget.showFaceGuide)
          FaceAlignmentGuide(
            validationResult: _currentResult,
            showGuide: !(_currentResult?.isValid ?? false),
          ),

        // Distance feedback overlay
        if (widget.showFeedbackOverlay)
          DistanceFeedbackOverlay(
            validationResult: _currentResult,
            position: widget.overlayPosition,
          ),

        // Test paused overlay
        if (_isTestPaused) _buildPausedOverlay(),
      ],
    );
  }

  Widget _buildCameraPreview() {
    if (!_cameraManager.isReady || _cameraManager.controller == null) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Opacity(
        opacity: 0.3,
        child: CameraPreview(_cameraManager.controller!),
      ),
    );
  }

  Widget _buildPausedOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.pause_circle_outline,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            const Text(
              'Test Paused',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _currentResult?.feedbackMessage ?? 'Adjust your position',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildErrorView() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 20),
              const Text(
                'Camera Error',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage ?? 'Unknown error',
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simplified distance validation-only widget (no continuous monitoring)
class DistanceValidationGuard extends StatefulWidget {
  /// Calibration data
  final DistanceCalibrationData calibrationData;

  /// Child to show after validation passes
  final Widget child;

  /// Validation success callback
  final VoidCallback? onValidated;

  const DistanceValidationGuard({
    super.key,
    required this.calibrationData,
    required this.child,
    this.onValidated,
  });

  @override
  State<DistanceValidationGuard> createState() =>
      _DistanceValidationGuardState();
}

class _DistanceValidationGuardState extends State<DistanceValidationGuard> {
  final DistanceDetectionService _distanceService = DistanceDetectionService();
  final CameraManagerService _cameraManager = CameraManagerService();

  bool _isValidated = false;
  DistanceValidationResult? _validationResult;
  int _consecutiveValidFrames = 0;
  static const _requiredValidFrames = 10; // Require 10 consecutive valid frames

  @override
  void initState() {
    super.initState();
    _startValidation();
  }

  Future<void> _startValidation() async {
    try {
      await _cameraManager.initialize(useFrontCamera: true);
      await _distanceService.initialize();
      _distanceService.setCalibration(widget.calibrationData);

      await _distanceService.startDetection();

      _distanceService.distanceStream.listen((result) {
        setState(() {
          _validationResult = result;
        });

        if (result.isValid) {
          _consecutiveValidFrames++;
          if (_consecutiveValidFrames >= _requiredValidFrames &&
              !_isValidated) {
            setState(() {
              _isValidated = true;
            });
            widget.onValidated?.call();
            _distanceService.stopDetection();
          }
        } else {
          _consecutiveValidFrames = 0;
        }
      });
    } catch (e) {
      debugPrint('Validation error: $e');
    }
  }

  @override
  void dispose() {
    _distanceService.stopDetection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isValidated) {
      return widget.child;
    }

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Camera preview
          if (_cameraManager.isReady && _cameraManager.controller != null)
            CameraPreview(_cameraManager.controller!),

          // Face guide
          FaceAlignmentGuide(validationResult: _validationResult),

          // Feedback
          DistanceFeedbackOverlay(
            validationResult: _validationResult,
            position: OverlayPosition.top,
          ),

          // Progress indicator
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  Text(
                    'Hold steady: ${_consecutiveValidFrames}/$_requiredValidFrames',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(
                      value: _consecutiveValidFrames / _requiredValidFrames,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
