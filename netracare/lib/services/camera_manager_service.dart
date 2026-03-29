// Camera Manager Service
// Centralized camera lifecycle management for all tests
// Prevents resource conflicts and ensures proper cleanup
// Author: NetraCare Team
// Date: January 26, 2026

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Singleton service for managing camera lifecycle
class CameraManagerService {
  static final CameraManagerService _instance =
      CameraManagerService._internal();
  factory CameraManagerService() => _instance;
  CameraManagerService._internal();

  /// Current camera controller
  CameraController? _controller;

  /// Available cameras on device
  List<CameraDescription>? _cameras;

  /// Is camera initialized?
  bool _isInitialized = false;

  /// Current camera being used (0 = back, 1 = front)
  int _currentCameraIndex = 1; // Default to front camera for face detection

  /// Camera resolution
  ResolutionPreset _resolution = ResolutionPreset.high;

  /// Stream controller for camera state changes
  final _stateChangeNotifier = ValueNotifier<CameraState>(
    CameraState.uninitialized,
  );

  /// Get state change notifier
  ValueNotifier<CameraState> get stateNotifier => _stateChangeNotifier;

  /// Get current controller
  CameraController? get controller => _controller;

  /// Is camera ready?
  bool get isReady => _isInitialized && _controller != null;

  /// Get current camera description
  CameraDescription? get currentCamera =>
      _cameras != null && _cameras!.isNotEmpty
      ? _cameras![_currentCameraIndex]
      : null;

  /// Initialize cameras
  Future<void> initialize({
    bool useFrontCamera = true,
    ResolutionPreset resolution = ResolutionPreset.high,
  }) async {
    try {
      _stateChangeNotifier.value = CameraState.initializing;

      // Get available cameras if not already loaded
      if (_cameras == null || _cameras!.isEmpty) {
        _cameras = await availableCameras();
        if (_cameras == null || _cameras!.isEmpty) {
          throw CameraException('NO_CAMERAS', 'No cameras available on device');
        }
      }

      // Select camera by lens direction (more reliable than index)
      CameraDescription selectedCamera;
      if (useFrontCamera) {
        try {
          // Find front camera
          final frontCameraIndex = _cameras!.indexWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
          );
          if (frontCameraIndex >= 0) {
            _currentCameraIndex = frontCameraIndex;
            selectedCamera = _cameras![frontCameraIndex];
          } else {
            // No front camera, use first available
            _currentCameraIndex = 0;
            selectedCamera = _cameras![0];
          }
        } catch (e) {
          _currentCameraIndex = 0;
          selectedCamera = _cameras![0];
        }
      } else {
        try {
          // Find back camera
          final backCameraIndex = _cameras!.indexWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
          );
          if (backCameraIndex >= 0) {
            _currentCameraIndex = backCameraIndex;
            selectedCamera = _cameras![backCameraIndex];
          } else {
            // No back camera, use first available
            _currentCameraIndex = 0;
            selectedCamera = _cameras![0];
          }
        } catch (e) {
          _currentCameraIndex = 0;
          selectedCamera = _cameras![0];
        }
      }

      _resolution = resolution;

      // Dispose existing controller if any
      await _disposeController();

      // Create new controller
      _controller = CameraController(
        selectedCamera,
        _resolution,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420, // Best for ML processing
      );

      // Initialize controller
      await _controller!.initialize();
      _isInitialized = true;
      _stateChangeNotifier.value = CameraState.ready;

      debugPrint(
        'CameraManager: Initialized ${selectedCamera.lensDirection} camera',
      );
    } catch (e) {
      _isInitialized = false;
      _stateChangeNotifier.value = CameraState.error;
      debugPrint('CameraManager: Initialization error: $e');
      rethrow;
    }
  }

  /// Switch between front and back camera
  Future<void> switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) {
      throw CameraException(
        'NO_ALTERNATE_CAMERA',
        'No alternate camera available',
      );
    }

    try {
      _stateChangeNotifier.value = CameraState.switching;

      // Toggle camera index
      _currentCameraIndex = _currentCameraIndex == 0 ? 1 : 0;

      // Reinitialize with new camera
      await _disposeController();
      _controller = CameraController(
        _cameras![_currentCameraIndex],
        _resolution,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      _isInitialized = true;
      _stateChangeNotifier.value = CameraState.ready;

      debugPrint(
        'CameraManager: Switched to ${_currentCameraIndex == 1 ? 'front' : 'back'} camera',
      );
    } catch (e) {
      _isInitialized = false;
      _stateChangeNotifier.value = CameraState.error;
      debugPrint('CameraManager: Camera switch error: $e');
      rethrow;
    }
  }

  /// Start image stream for real-time processing
  Future<void> startImageStream(Function(CameraImage) onImage) async {
    if (!isReady) {
      throw CameraException('NOT_INITIALIZED', 'Camera not initialized');
    }

    if (_controller!.value.isStreamingImages) {
      debugPrint('CameraManager: Image stream already active');
      return;
    }

    try {
      await _controller!.startImageStream(onImage);
      _stateChangeNotifier.value = CameraState.streaming;
      debugPrint('CameraManager: Image stream started');
    } catch (e) {
      debugPrint('CameraManager: Error starting image stream: $e');
      rethrow;
    }
  }

  /// Stop image stream
  Future<void> stopImageStream() async {
    if (_controller == null || !_controller!.value.isStreamingImages) {
      return;
    }

    try {
      await _controller!.stopImageStream();
      _stateChangeNotifier.value = CameraState.ready;
      debugPrint('CameraManager: Image stream stopped');
    } catch (e) {
      debugPrint('CameraManager: Error stopping image stream: $e');
    }
  }

  /// Dispose controller
  Future<void> _disposeController() async {
    if (_controller != null) {
      try {
        if (_controller!.value.isStreamingImages) {
          await _controller!.stopImageStream();
        }
        await _controller!.dispose();
        _controller = null;
        _isInitialized = false;
      } catch (e) {
        debugPrint('CameraManager: Error disposing controller: $e');
      }
    }
  }

  /// Dispose all resources
  Future<void> dispose() async {
    await _disposeController();
    _stateChangeNotifier.value = CameraState.disposed;
    debugPrint('CameraManager: Service disposed');
  }

  /// Get camera sensor orientation
  int get sensorOrientation => currentCamera?.sensorOrientation ?? 0;

  /// Is front camera active?
  bool get isFrontCamera =>
      currentCamera?.lensDirection == CameraLensDirection.front;

  /// Get camera resolution
  Size? get resolution => _controller?.value.previewSize;

  /// Estimate focal length (approximation for typical phone cameras)
  /// Focal length = (sensor_width_pixels * distance) / real_world_width
  double estimateFocalLength({
    required double measuredDistanceCm,
    required double realWorldWidthCm,
    required double pixelWidth,
  }) {
    // Focal length in pixels = (pixel_width * distance) / real_width
    return (pixelWidth * measuredDistanceCm) / realWorldWidthCm;
  }
}

/// Camera state enum
enum CameraState {
  uninitialized,
  initializing,
  ready,
  streaming,
  switching,
  error,
  disposed,
}
