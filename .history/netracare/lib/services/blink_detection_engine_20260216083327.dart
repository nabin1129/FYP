import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class BlinkDetectionEngine {
  BlinkDetectionEngine({
    int frameSkipInterval = 2,
    int minClosedFrames = 1,
    int debounceMs = 250,
    double eyeClosedProbabilityThreshold = 0.4,
  })  : _frameSkipInterval = frameSkipInterval,
        _minClosedFrames = minClosedFrames,
        _debounceMs = debounceMs,
        _eyeClosedProbabilityThreshold = eyeClosedProbabilityThreshold {
    final options = FaceDetectorOptions(
      enableLandmarks: false,
      enableContours: false,
      enableClassification: true,
      enableTracking: true,
      minFaceSize: 0.15,
      performanceMode: FaceDetectorMode.fast,
    );
    _faceDetector = FaceDetector(options: options);
  }

  late final FaceDetector _faceDetector;

  final int _frameSkipInterval;
  final int _minClosedFrames;
  final int _debounceMs;
  final double _eyeClosedProbabilityThreshold;

  bool _isDetecting = false;
  bool _isProcessing = false;
  bool _eyesClosed = false;
  int _frameSkipCounter = 0;
  int _closedFrames = 0;
  int _blinkCount = 0;
  DateTime? _lastBlinkAt;

  int get blinkCount => _blinkCount;
  bool get isDetecting => _isDetecting;

  Future<void> start(
    CameraController controller,
    void Function(int) onBlinkDetected, {
    void Function(String)? onError,
  }) async {
    if (_isDetecting) {
      return;
    }

    if (!controller.value.isInitialized) {
      onError?.call('Camera not initialized');
      return;
    }

    _isDetecting = true;
    _frameSkipCounter = 0;
    _closedFrames = 0;
    _eyesClosed = false;

    if (!controller.value.isStreamingImages) {
      await controller.startImageStream(
        (image) => _processFrame(image, controller, onBlinkDetected, onError),
      );
    }
  }

  Future<void> stop(CameraController controller) async {
    if (!_isDetecting) {
      return;
    }

    _isDetecting = false;
    _isProcessing = false;

    if (controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (e) {
        debugPrint('BlinkDetectionEngine: stopImageStream error: $e');
      }
    }
  }

  void reset() {
    _blinkCount = 0;
    _closedFrames = 0;
    _eyesClosed = false;
    _lastBlinkAt = null;
  }

  void dispose() {
    _faceDetector.close();
  }

  Future<void> _processFrame(
    CameraImage image,
    CameraController controller,
    void Function(int) onBlinkDetected,
    void Function(String)? onError,
  ) async {
    if (!_isDetecting || _isProcessing) {
      return;
    }

    _frameSkipCounter++;
    if (_frameSkipCounter % _frameSkipInterval != 0) {
      return;
    }

    _isProcessing = true;

    try {
      final inputImage = _convertCameraImage(image, controller);
      if (inputImage == null) {
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isEmpty) {
        return;
      }

      final face = faces.first;
      final leftProb = face.leftEyeOpenProbability;
      final rightProb = face.rightEyeOpenProbability;

      if (leftProb == null || rightProb == null) {
        return;
      }

      final eyesClosed =
          leftProb < _eyeClosedProbabilityThreshold &&
          rightProb < _eyeClosedProbabilityThreshold;

      if (eyesClosed) {
        _closedFrames++;
        _eyesClosed = true;
      } else {
        if (_eyesClosed && _closedFrames >= _minClosedFrames) {
          if (_canCountBlink()) {
            _blinkCount++;
            _lastBlinkAt = DateTime.now();
            onBlinkDetected(_blinkCount);
          }
        }
        _closedFrames = 0;
        _eyesClosed = false;
      }
    } catch (e) {
      onError?.call('Blink detection error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _convertCameraImage(
    CameraImage image,
    CameraController controller,
  ) {
    try {
      final rotation = InputImageRotationValue.fromRawValue(
        controller.description.sensorOrientation,
      );
      if (rotation == null) {
        return null;
      }

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) {
        return null;
      }

      final plane = image.planes[0];
      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      );

      return InputImage.fromBytes(bytes: plane.bytes, metadata: metadata);
    } catch (e) {
      debugPrint('BlinkDetectionEngine: Image conversion error: $e');
      return null;
    }
  }

  bool _canCountBlink() {
    if (_lastBlinkAt == null) {
      return true;
    }
    final elapsedMs =
        DateTime.now().difference(_lastBlinkAt!).inMilliseconds;
    return elapsedMs >= _debounceMs;
  }
}
