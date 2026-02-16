/// Distance Detection Service
/// Real-time distance measurement using IPD-based depth estimation
/// Implements: Distance = (FocalLength × RealIPD) / PixelIPD
/// Author: NetraCare Team
/// Date: January 26, 2026

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/distance_calibration_model.dart';
import 'camera_manager_service.dart';

/// Singleton service for real-time distance detection
class DistanceDetectionService {
  static final DistanceDetectionService _instance =
      DistanceDetectionService._internal();
  factory DistanceDetectionService() => _instance;
  DistanceDetectionService._internal();

  /// Debug mode: Allows testing without real face detection
  /// Set to true for emulator/simulator testing
  bool debugMode = kDebugMode && false; // Disabled by default

  /// ML Kit Face Detector
  FaceDetector? _faceDetector;

  /// Camera manager
  final CameraManagerService _cameraManager = CameraManagerService();

  /// Current calibration data
  DistanceCalibrationData? _calibrationData;

  /// Is detection active?
  bool _isDetecting = false;

  /// Frame skip counter for performance optimization
  int _frameSkipCounter = 0;

  /// Process every Nth frame (3 = 10 FPS on 30 FPS camera)
  final int _frameSkipInterval = 3;

  /// Stream controller for distance updates
  final _distanceStreamController =
      StreamController<DistanceValidationResult>.broadcast();

  /// Stream of distance validation results
  Stream<DistanceValidationResult> get distanceStream =>
      _distanceStreamController.stream;

  /// Last validation result (cached)
  DistanceValidationResult? _lastResult;

  /// Get last result
  DistanceValidationResult? get lastResult => _lastResult;

  /// Is currently detecting?
  bool get isDetecting => _isDetecting;

  /// Has calibration data?
  bool get isCalibrated => _calibrationData != null;

  /// Initialize face detector
  Future<void> initialize() async {
    if (_faceDetector != null) {
      debugPrint('DistanceDetection: Already initialized');
      return;
    }

    try {
      // Configure face detector for optimal landmark detection
      final options = FaceDetectorOptions(
        enableLandmarks: true, // Required for eye/IPD detection
        enableContours: true, // For face outline
        enableClassification: false, // Not needed for distance
        enableTracking: true, // Improve performance
        minFaceSize: 0.15, // Minimum 15% of image
        performanceMode: FaceDetectorMode.accurate, // Accuracy over speed
      );

      _faceDetector = FaceDetector(options: options);
      debugPrint('DistanceDetection: Face detector initialized (Debug mode: $debugMode)');
    } catch (e) {
      debugPrint('DistanceDetection: Initialization error: $e');
      throw Exception('Failed to initialize face detection. Please ensure camera permissions are granted.');
    }
  }

  /// Set calibration data
  void setCalibration(DistanceCalibrationData calibration) {
    _calibrationData = calibration;
    debugPrint(
      'DistanceDetection: Calibration set - ref: ${calibration.referenceDistance}cm, '
      'IPD: ${calibration.baselineIpdPixels}px',
    );
  }

  /// Clear calibration
  void clearCalibration() {
    _calibrationData = null;
    debugPrint('DistanceDetection: Calibration cleared');
  }

  /// Start real-time distance detection
  Future<void> startDetection() async {
    if (_isDetecting) {
      debugPrint('DistanceDetection: Already detecting');
      return;
    }

    if (_faceDetector == null) {
      await initialize();
    }

    if (!debugMode && !_cameraManager.isReady) {
      throw Exception('Camera not ready. Please ensure camera permissions are granted and try again.');
    }

    try {
      _isDetecting = true;
      _frameSkipCounter = 0;

      if (!debugMode) {
        await _cameraManager.startImageStream(_processImageFrame);
      }
      debugPrint('DistanceDetection: Detection started (Debug: $debugMode)');
    } catch (e) {
      _isDetecting = false;
      debugPrint('DistanceDetection: Error starting detection: $e');
      throw Exception('Failed to start camera stream. Please check camera permissions.');
    }
  }

  /// Stop distance detection
  Future<void> stopDetection() async {
    if (!_isDetecting) {
      return;
    }

    try {
      await _cameraManager.stopImageStream();
      _isDetecting = false;
      debugPrint('DistanceDetection: Detection stopped');
    } catch (e) {
      debugPrint('DistanceDetection: Error stopping detection: $e');
    }
  }

  /// Process individual camera frame
  Future<void> _processImageFrame(CameraImage image) async {
    // Frame throttling: process every Nth frame for performance
    _frameSkipCounter++;
    if (_frameSkipCounter % _frameSkipInterval != 0) {
      return;
    }

    // Skip if still processing previous frame
    if (!_isDetecting) {
      return;
    }

    try {
      // Convert CameraImage to InputImage for ML Kit
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        debugPrint('DistanceDetection: Failed to convert camera image');
        return;
      }

      // Detect faces
      final faces = await _faceDetector!.processImage(inputImage);

      // Validate and calculate distance
      final result = _validateDistance(faces);

      // Update stream
      _lastResult = result;
      if (!_distanceStreamController.isClosed) {
        _distanceStreamController.add(result);
      }
    } catch (e) {
      debugPrint('DistanceDetection: Frame processing error: $e');
      // Don't throw - continue processing next frames
    }
  }

  /// Convert CameraImage to ML Kit InputImage
  InputImage? _convertCameraImage(CameraImage image) {
    try {
      // Get image rotation
      final camera = _cameraManager.currentCamera;
      if (camera == null) return null;

      final sensorOrientation = camera.sensorOrientation;
      final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      if (rotation == null) return null;

      // Get image format
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      // Get plane data
      final plane = image.planes[0];
      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      );

      return InputImage.fromBytes(bytes: plane.bytes, metadata: metadata);
    } catch (e) {
      debugPrint('DistanceDetection: Image conversion error: $e');
      return null;
    }
  }

  /// Validate distance from detected faces
  DistanceValidationResult _validateDistance(List<Face> faces) {
    // No calibration data
    if (_calibrationData == null) {
      return DistanceValidationResult(
        currentDistance: 0,
        referenceDistance: 0,
        delta: 0,
        isValid: false,
        toleranceCm: 3.0,
        status: DistanceStatus.error,
      );
    }

    // No face detected
    if (faces.isEmpty) {
      return DistanceValidationResult(
        currentDistance: 0,
        referenceDistance: _calibrationData!.referenceDistance,
        delta: _calibrationData!.referenceDistance,
        isValid: false,
        toleranceCm: _calibrationData!.toleranceCm,
        status: DistanceStatus.noFaceDetected,
      );
    }

    // Multiple faces detected
    if (faces.length > 1) {
      return DistanceValidationResult(
        currentDistance: 0,
        referenceDistance: _calibrationData!.referenceDistance,
        delta: _calibrationData!.referenceDistance,
        isValid: false,
        toleranceCm: _calibrationData!.toleranceCm,
        status: DistanceStatus.multipleFaces,
      );
    }

    // Calculate distance from single face
    final face = faces.first;
    final currentDistance = _calculateDistance(face);

    if (currentDistance == null) {
      return DistanceValidationResult(
        currentDistance: 0,
        referenceDistance: _calibrationData!.referenceDistance,
        delta: _calibrationData!.referenceDistance,
        isValid: false,
        toleranceCm: _calibrationData!.toleranceCm,
        status: DistanceStatus.error,
      );
    }

    // Calculate delta and status
    final delta = currentDistance - _calibrationData!.referenceDistance;
    final absDelta = delta.abs();
    final tolerance = _calibrationData!.toleranceCm;

    DistanceStatus status;
    bool isValid;

    if (absDelta <= 1.0) {
      // Perfect: within ±1 cm
      status = DistanceStatus.perfect;
      isValid = true;
    } else if (absDelta <= tolerance) {
      // Acceptable: within tolerance
      status = DistanceStatus.acceptable;
      isValid = true;
    } else if (delta < 0) {
      // Too close
      status = DistanceStatus.tooClose;
      isValid = false;
    } else {
      // Too far
      status = DistanceStatus.tooFar;
      isValid = false;
    }

    return DistanceValidationResult(
      currentDistance: currentDistance,
      referenceDistance: _calibrationData!.referenceDistance,
      delta: delta,
      isValid: isValid,
      toleranceCm: tolerance,
      status: status,
      detectedIpdPixels: _calculateIpdPixels(face),
    );
  }

  /// Calculate distance using IPD-based estimation
  /// Formula: Distance = (FocalLength × RealIPD) / PixelIPD
  double? _calculateDistance(Face face) {
    try {
      // Get eye landmarks
      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];

      if (leftEye == null || rightEye == null) {
        // Fallback to face width estimation
        return _estimateDistanceFromFaceWidth(face);
      }

      // Calculate IPD in pixels
      final ipdPixels = _calculateIpdPixels(face);
      if (ipdPixels == null || ipdPixels < 10) {
        // IPD too small, invalid detection
        return null;
      }

      // Calculate distance
      // Distance = (FocalLength × RealIPD) / PixelIPD
      final distance =
          (_calibrationData!.focalLength * _calibrationData!.realWorldIpd) /
          ipdPixels;

      return distance;
    } catch (e) {
      debugPrint('DistanceDetection: Distance calculation error: $e');
      return null;
    }
  }

  /// Calculate IPD (interpupillary distance) in pixels
  double? _calculateIpdPixels(Face face) {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];

    if (leftEye == null || rightEye == null) {
      return null;
    }

    // Euclidean distance between eyes
    final dx = rightEye.position.x.toDouble() - leftEye.position.x.toDouble();
    final dy = rightEye.position.y.toDouble() - leftEye.position.y.toDouble();
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Fallback: estimate distance from face bounding box width
  double? _estimateDistanceFromFaceWidth(Face face) {
    final faceWidth = face.boundingBox.width;

    if (faceWidth < 50) {
      // Face too small, invalid
      return null;
    }

    // Average adult face width: ~14 cm
    const avgFaceWidthCm = 14.0;

    // Distance = (FocalLength × RealWidth) / PixelWidth
    final distance =
        (_calibrationData!.focalLength * avgFaceWidthCm) / faceWidth;

    return distance;
  }

  /// Perform calibration from detected face
  /// User should be at arm's length (~45 cm)
  Future<DistanceCalibrationData?> performCalibration({
    required String userId,
    required double referenceDistanceCm,
  }) async {
    if (_faceDetector == null) {
      await initialize();
    }

    if (!debugMode && !_cameraManager.isReady) {
      throw Exception('Camera not ready. Please ensure camera permissions are granted.');
    }

    // Debug mode: Return mock calibration data
    if (debugMode) {
      debugPrint('DistanceDetection: Using mock calibration (Debug mode)');
      return DistanceCalibrationData(
        userId: int.parse(userId),
        calibratedAt: DateTime.now(),
        referenceDistance: referenceDistanceCm,
        baselineIpdPixels: 180.0,
        baselineFaceWidthPixels: 320.0,
        focalLength: 1285.7,
        realWorldIpd: 6.3,
        toleranceCm: 3.0,
        deviceModel: 'Emulator',
        cameraResolution: '640x480',
        isActive: true,
      );
    }

    try {
      // Capture single frame
      final image = await _captureSingleFrame();
      if (image == null) {
        throw Exception('Failed to capture calibration image');
      }

      // Detect face
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        throw Exception('Failed to convert image');
      }

      final faces = await _faceDetector!.processImage(inputImage);

      if (faces.isEmpty) {
        throw Exception(
          'No face detected. Please ensure:\n'
          '• Your face is clearly visible\n'
          '• You are in a well-lit area\n'
          '• The camera is not obstructed',
        );
      }

      if (faces.length > 1) {
        throw Exception(
          'Multiple faces detected. Please ensure:\n'
          '• Only one person is visible to the camera\n'
          '• No photos or faces in the background',
        );
      }

      final face = faces.first;

      // Calculate baseline IPD
      final ipdPixels = _calculateIpdPixels(face);
      if (ipdPixels == null || ipdPixels < 10) {
        throw Exception(
          'Could not detect eye landmarks. Please:\n'
          '• Face the camera directly\n'
          '• Remove glasses (if wearing)\n'
          '• Ensure good lighting on your face\n'
          '• Keep your eyes open and clearly visible',
        );
      }

      // Calculate face width
      final faceWidthPixels = face.boundingBox.width.toDouble();

      // Calculate focal length
      // FocalLength = (PixelIPD × Distance) / RealIPD
      const realIpd = 6.3; // Average adult IPD in cm
      final focalLength = (ipdPixels * referenceDistanceCm) / realIpd;

      // Get device info
      final resolution = _cameraManager.resolution;
      final deviceModel = 'Unknown'; // TODO: Get from device_info_plus package

      final calibrationData = DistanceCalibrationData(
        userId: int.parse(userId),
        calibratedAt: DateTime.now(),
        referenceDistance: referenceDistanceCm,
        baselineIpdPixels: ipdPixels,
        baselineFaceWidthPixels: faceWidthPixels,
        focalLength: focalLength,
        realWorldIpd: realIpd,
        toleranceCm: 3.0,
        deviceModel: deviceModel,
        cameraResolution: resolution != null
            ? '${resolution.width.toInt()}x${resolution.height.toInt()}'
            : null,
        isActive: true,
      );

      debugPrint(
        'DistanceDetection: Calibration successful - $calibrationData',
      );
      return calibrationData;
    } catch (e) {
      debugPrint('DistanceDetection: Calibration error: $e');
      rethrow;
    }
  }

  /// Capture single frame for calibration
  Future<CameraImage?> _captureSingleFrame() async {
    final completer = Completer<CameraImage?>();
    bool captured = false;

    void onImage(CameraImage image) {
      if (!captured) {
        captured = true;
        completer.complete(image);
      }
    }

    await _cameraManager.startImageStream(onImage);
    final image = await completer.future;
    await _cameraManager.stopImageStream();

    return image;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopDetection();
    await _faceDetector?.close();
    _faceDetector = null;
    await _distanceStreamController.close();
    debugPrint('DistanceDetection: Service disposed');
  }
}
