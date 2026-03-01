/// Eye Tracking Engine — Real-time camera-based gaze estimation
/// Uses Google ML Kit FaceDetector with contours + classification
/// to estimate gaze direction, compute EAR, and detect blinks/saccades.
///
/// Follows the same pattern as BlinkDetectionEngine for consistency.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/eye_tracking_data.dart';

/// Callback with the latest processed frame data
typedef OnFrameProcessed = void Function(EyeTrackingFrame frame);

/// Callback when face is detected or lost
typedef OnFaceStatusChanged = void Function(bool faceDetected);

class EyeTrackingEngine {
  EyeTrackingEngine({
    int frameSkipInterval = 2,
    double blinkThreshold = 0.4,
    double saccadeVelocityThreshold = 200.0,
  }) : _frameSkipInterval = frameSkipInterval,
       _blinkThreshold = blinkThreshold,
       _saccadeVelocityThreshold = saccadeVelocityThreshold {
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
  }

  late final FaceDetector _faceDetector;
  final int _frameSkipInterval;
  final double _blinkThreshold;
  final double _saccadeVelocityThreshold;

  // ─── State ────────────────────────────────────────────────────────────────
  bool _isRunning = false;
  bool _isProcessing = false;
  int _frameCounter = 0;
  int _faceDetectedCount = 0;
  int _noFaceCount = 0;

  // Blink detection state
  bool _eyesClosed = false;
  int _closedFrameCount = 0;
  DateTime? _lastBlinkTime;

  // Previous gaze for saccade detection
  GazePoint? _previousGaze;

  // Session data
  final EyeTrackingSessionData _sessionData = EyeTrackingSessionData();

  // Screen dimensions (set before starting)
  Size _screenSize = Size.zero;

  // ─── Getters ──────────────────────────────────────────────────────────────
  bool get isRunning => _isRunning;
  int get faceDetectedCount => _faceDetectedCount;
  int get noFaceCount => _noFaceCount;
  EyeTrackingSessionData get sessionData => _sessionData;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  Future<void> start(
    CameraController controller, {
    required Size screenSize,
    required OnFrameProcessed onFrameProcessed,
    OnFaceStatusChanged? onFaceStatus,
    void Function(String)? onError,
  }) async {
    if (_isRunning) return;
    if (!controller.value.isInitialized) {
      onError?.call('Camera not initialized');
      return;
    }

    _isRunning = true;
    _frameCounter = 0;
    _screenSize = screenSize;
    _sessionData.screenWidth = screenSize.width.toInt();
    _sessionData.screenHeight = screenSize.height.toInt();

    if (!controller.value.isStreamingImages) {
      await controller.startImageStream(
        (image) => _processFrame(
          image,
          controller,
          onFrameProcessed,
          onFaceStatus,
          onError,
        ),
      );
    }
  }

  Future<void> stop(CameraController controller) async {
    if (!_isRunning) return;
    _isRunning = false;
    _isProcessing = false;

    if (controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (e) {
        debugPrint('EyeTrackingEngine: stopImageStream error: $e');
      }
    }
  }

  void reset() {
    _faceDetectedCount = 0;
    _noFaceCount = 0;
    _eyesClosed = false;
    _closedFrameCount = 0;
    _lastBlinkTime = null;
    _previousGaze = null;
    _sessionData.frames.clear();
    _sessionData.saccades.clear();
    _sessionData.microsaccades.clear();
    _sessionData.pursuits.clear();
    _sessionData.blinkCount = 0;
    _sessionData.testDurationSeconds = 0;
  }

  void dispose() {
    _faceDetector.close();
  }

  // ─── Frame Processing ─────────────────────────────────────────────────────

  Future<void> _processFrame(
    CameraImage image,
    CameraController controller,
    OnFrameProcessed onFrameProcessed,
    OnFaceStatusChanged? onFaceStatus,
    void Function(String)? onError,
  ) async {
    if (!_isRunning || _isProcessing) return;

    _frameCounter++;
    if (_frameCounter % _frameSkipInterval != 0) return;

    _isProcessing = true;

    try {
      final inputImage = _convertCameraImage(image, controller);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        _noFaceCount++;
        onFaceStatus?.call(false);
        return;
      }

      _faceDetectedCount++;
      onFaceStatus?.call(true);

      final face = faces.first;
      final gazePoint = _estimateGaze(face);
      _calculateEAR(face, FaceContourType.leftEye);
      _calculateEAR(face, FaceContourType.rightEye);
      final isBlink = _detectBlink(face);

      // Detect saccades
      if (_previousGaze != null && gazePoint != null && !isBlink) {
        final dt = gazePoint.timestamp - _previousGaze!.timestamp;
        if (dt > 0) {
          final distance = gazePoint.distanceTo(_previousGaze!);
          final velocity = distance / dt; // pixels/sec

          if (velocity > _saccadeVelocityThreshold) {
            _sessionData.addSaccade(
              SaccadeEvent(
                startPoint: _previousGaze!,
                endPoint: gazePoint,
                velocity: velocity,
                amplitude: distance,
                duration: dt,
              ),
            );
          }
        }
      }

      if (gazePoint != null) {
        _previousGaze = gazePoint;
      }
    } catch (e) {
      onError?.call('Eye tracking error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // ─── Gaze Estimation ──────────────────────────────────────────────────────
  // Uses head euler angles + eye contour centroid offset from face center
  // to estimate where on screen the user is looking.

  GazePoint? _estimateGaze(Face face) {
    final headY =
        face.headEulerAngleY ?? 0; // yaw: negative=left, positive=right
    final headX =
        face.headEulerAngleX ?? 0; // pitch: negative=down, positive=up

    // Get eye contours for finer estimation
    final leftEyeContour = face.contours[FaceContourType.leftEye];
    final rightEyeContour = face.contours[FaceContourType.rightEye];

    double eyeOffsetX = 0;
    double eyeOffsetY = 0;

    if (leftEyeContour != null && rightEyeContour != null) {
      // Compute the centroid of each eye contour
      final leftCenter = _contourCenter(leftEyeContour.points);
      final rightCenter = _contourCenter(rightEyeContour.points);

      // Midpoint between both eyes
      final eyeMidpoint = Offset(
        (leftCenter.dx + rightCenter.dx) / 2,
        (leftCenter.dy + rightCenter.dy) / 2,
      );

      // Face bounding box center
      final faceCenter = Offset(
        face.boundingBox.center.dx,
        face.boundingBox.center.dy,
      );

      // Eye offset relative to face center (normalized)
      final faceWidth = face.boundingBox.width;
      final faceHeight = face.boundingBox.height;
      if (faceWidth > 0 && faceHeight > 0) {
        eyeOffsetX = (eyeMidpoint.dx - faceCenter.dx) / faceWidth;
        eyeOffsetY = (eyeMidpoint.dy - faceCenter.dy) / faceHeight;
      }
    }

    // Map head rotation + eye offset to screen coordinates
    // Yaw: -35° to +35° maps to screen width
    // Pitch: -25° to +25° maps to screen height
    final normalizedX = (headY / 35.0).clamp(-1.0, 1.0) + eyeOffsetX * 2;
    final normalizedY = (-headX / 25.0).clamp(-1.0, 1.0) + eyeOffsetY * 2;

    // Map [-1, 1] to screen coordinates
    final gazeX = _screenSize.width / 2 + normalizedX * (_screenSize.width / 2);
    final gazeY =
        _screenSize.height / 2 + normalizedY * (_screenSize.height / 2);

    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;

    return GazePoint(
      x: gazeX.clamp(0, _screenSize.width),
      y: gazeY.clamp(0, _screenSize.height),
      timestamp: now,
      confidence: leftEyeContour != null ? 0.85 : 0.5,
    );
  }

  Offset _contourCenter(List<math.Point<int>> points) {
    if (points.isEmpty) return Offset.zero;
    double sumX = 0, sumY = 0;
    for (final p in points) {
      sumX += p.x;
      sumY += p.y;
    }
    return Offset(sumX / points.length, sumY / points.length);
  }

  // ─── EAR Calculation ──────────────────────────────────────────────────────
  // Eye Aspect Ratio from 16-point eye contour:
  // EAR = (|p4-p12| + |p5-p11|) / (2 * |p0-p8|)

  double _calculateEAR(Face face, FaceContourType eyeType) {
    final contour = face.contours[eyeType];
    if (contour == null || contour.points.length < 16) {
      // Fall back to eye-open probability
      if (eyeType == FaceContourType.leftEye) {
        return (face.leftEyeOpenProbability ?? 0.5) * 0.4;
      } else {
        return (face.rightEyeOpenProbability ?? 0.5) * 0.4;
      }
    }

    final pts = contour.points;
    // Vertical distances
    final v1 = _pointDistance(pts[4], pts[12]);
    final v2 = _pointDistance(pts[5], pts[11]);
    // Horizontal distance
    final h = _pointDistance(pts[0], pts[8]);

    if (h == 0) return 0;
    return (v1 + v2) / (2.0 * h);
  }

  double _pointDistance(math.Point<int> a, math.Point<int> b) {
    return math.sqrt(
      math.pow((a.x - b.x).toDouble(), 2) + math.pow((a.y - b.y).toDouble(), 2),
    );
  }

  // ─── Blink Detection ──────────────────────────────────────────────────────

  bool _detectBlink(Face face) {
    final leftProb = face.leftEyeOpenProbability;
    final rightProb = face.rightEyeOpenProbability;

    if (leftProb == null || rightProb == null) return false;

    final eyesClosed =
        leftProb < _blinkThreshold && rightProb < _blinkThreshold;

    if (eyesClosed) {
      _closedFrameCount++;
      _eyesClosed = true;
      return true;
    } else {
      if (_eyesClosed && _closedFrameCount >= 1) {
        // Blink just ended
        final now = DateTime.now();
        if (_lastBlinkTime == null ||
            now.difference(_lastBlinkTime!).inMilliseconds >= 250) {
          _sessionData.blinkCount++;
          _lastBlinkTime = now;
        }
      }
      _closedFrameCount = 0;
      _eyesClosed = false;
      return false;
    }
  }

  // ─── Record Frame ─────────────────────────────────────────────────────────
  // Called externally by the test page to record a frame with target position.

  EyeTrackingFrame? recordFrame({
    required Face face,
    required Offset targetPosition,
    required String phase,
    required double timestamp,
  }) {
    final gazePoint = _estimateGaze(face);
    if (gazePoint == null) return null;

    final leftEAR = _calculateEAR(face, FaceContourType.leftEye);
    final rightEAR = _calculateEAR(face, FaceContourType.rightEye);
    final isBlink = _detectBlink(face);

    final frame = EyeTrackingFrame(
      timestamp: timestamp,
      gazePoint: GazePoint(
        x: gazePoint.x,
        y: gazePoint.y,
        timestamp: timestamp,
        confidence: gazePoint.confidence,
      ),
      targetPosition: targetPosition,
      leftEAR: leftEAR,
      rightEAR: rightEAR,
      isBlink: isBlink,
      headEulerX: face.headEulerAngleX ?? 0,
      headEulerY: face.headEulerAngleY ?? 0,
      headEulerZ: face.headEulerAngleZ ?? 0,
      leftEyeOpenProb: face.leftEyeOpenProbability,
      rightEyeOpenProb: face.rightEyeOpenProbability,
      phase: phase,
    );

    _sessionData.addFrame(frame);

    // Saccade detection between consecutive frames
    if (_previousGaze != null && !isBlink) {
      final dt = timestamp - _previousGaze!.timestamp;
      if (dt > 0) {
        final distance = gazePoint.distanceTo(_previousGaze!);
        final velocity = distance / dt;
        if (velocity > _saccadeVelocityThreshold) {
          _sessionData.addSaccade(
            SaccadeEvent(
              startPoint: _previousGaze!,
              endPoint: gazePoint,
              velocity: velocity,
              amplitude: distance,
              duration: dt,
            ),
          );
        }
      }
    }
    _previousGaze = gazePoint;

    return frame;
  }

  // ─── Pursuit Analysis ─────────────────────────────────────────────────────

  PursuitSegment analyzePursuit(
    String direction,
    List<EyeTrackingFrame> phaseFrames,
  ) {
    if (phaseFrames.length < 3) {
      return PursuitSegment(
        direction: direction,
        accuracy: 0,
        smoothness: 0,
        saccadeCount: 0,
      );
    }

    // Calculate accuracy: mean distance from gaze to target
    final nonBlinkFrames = phaseFrames.where((f) => !f.isBlink).toList();
    double totalError = 0;
    for (final f in nonBlinkFrames) {
      totalError += f.gazeError;
    }
    final meanError = nonBlinkFrames.isNotEmpty
        ? totalError / nonBlinkFrames.length
        : 999;

    final diagonal = math.sqrt(
      math.pow(_screenSize.width, 2) + math.pow(_screenSize.height, 2),
    );
    final accuracy = diagonal > 0
        ? (100 - (meanError / diagonal * 400)).clamp(0.0, 100.0)
        : 0.0;

    // Smoothness: ratio of non-saccadic frames
    int saccadicFrames = 0;
    for (int i = 1; i < nonBlinkFrames.length; i++) {
      final dt = nonBlinkFrames[i].timestamp - nonBlinkFrames[i - 1].timestamp;
      if (dt > 0) {
        final dist = nonBlinkFrames[i].gazePoint.distanceTo(
          nonBlinkFrames[i - 1].gazePoint,
        );
        final vel = dist / dt;
        if (vel > _saccadeVelocityThreshold) saccadicFrames++;
      }
    }

    final smoothness = nonBlinkFrames.length > 1
        ? (1.0 - saccadicFrames / (nonBlinkFrames.length - 1)).clamp(0.0, 1.0)
        : 0.0;

    return PursuitSegment(
      direction: direction,
      accuracy: accuracy,
      smoothness: smoothness,
      saccadeCount: saccadicFrames,
    );
  }

  // ─── Image Conversion (same as BlinkDetectionEngine) ──────────────────────

  InputImage? _convertCameraImage(
    CameraImage image,
    CameraController controller,
  ) {
    try {
      final rotation = InputImageRotationValue.fromRawValue(
        controller.description.sensorOrientation,
      );
      if (rotation == null) return null;

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      final plane = image.planes[0];
      final allBytes = WriteBuffer();
      for (final imagePlane in image.planes) {
        allBytes.putUint8List(imagePlane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();
      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      debugPrint('EyeTrackingEngine: Image conversion error: $e');
      return null;
    }
  }
}
