import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Camera Service for Test Mode
///
/// Provides laptop webcam access for testing eye detection models.
/// This service wraps the camera package to simplify usage.
class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;

  /// Check if camera is initialized
  bool get isInitialized => _isInitialized && _controller != null;

  /// Get the camera controller
  CameraController? get controller => _controller;

  /// Initialize camera with optimal settings
  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('No cameras found on this device');
      }

      // Prefer front camera for eye tests, fallback to any available camera
      CameraDescription camera;
      try {
        camera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
        );
      } catch (e) {
        camera = _cameras!.first;
      }

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      throw Exception('Camera initialization failed: ${e.toString()}');
    }
  }

  /// Capture image from camera and save to temporary storage
  ///
  /// Returns the absolute file path of the captured image.
  Future<String> captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw Exception('Camera not initialized. Call initialize() first.');
    }

    try {
      // Capture the image
      final XFile image = await _controller!.takePicture();

      // Save to temporary directory with timestamp
      final Directory tempDir = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = 'eye_test_$timestamp.jpg';
      final String filePath = path.join(tempDir.path, fileName);

      // Copy the file to the new path
      await File(image.path).copy(filePath);

      return filePath;
    } catch (e) {
      throw Exception('Image capture failed: ${e.toString()}');
    }
  }

  /// Switch between front and back cameras
  Future<void> switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) {
      throw Exception('No alternative camera available');
    }

    final currentLensDirection = _controller?.description.lensDirection;

    // Find a camera with different lens direction
    CameraDescription? newCamera;
    try {
      newCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection != currentLensDirection,
      );
    } catch (e) {
      throw Exception('No alternative camera found');
    }

    // Dispose current controller
    await dispose();

    // Create new controller with different camera
    _controller = CameraController(
      newCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();
    _isInitialized = true;
  }

  /// Get list of available cameras
  List<CameraDescription>? getAvailableCameras() {
    return _cameras;
  }

  /// Check if device has multiple cameras
  bool hasMultipleCameras() {
    return _cameras != null && _cameras!.length > 1;
  }

  /// Dispose camera resources
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }
}
