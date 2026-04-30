import 'package:camera/camera.dart';

/// Recommended camera resolution for optimal test results.
const int _recommendedResolutionWidth = 1920;
const int _recommendedResolutionHeight = 1080;

/// Face-to-camera distance range in cm.
const double _minDistanceCm = 28;
const double _maxDistanceCm = 38;

enum PreCheckStatus { pass, warning, fail, unavailable }

class PreCheckResult {
  final PreCheckStatus cameraResolution;
  final String? cameraResolutionDetail;

  const PreCheckResult({
    required this.cameraResolution,
    this.cameraResolutionDetail,
  });

  bool get canProceed => cameraResolution != PreCheckStatus.fail;
}

class DevicePreCheckService {
  /// Check camera resolution and warn if below recommended specs.
  /// Low resolution cameras can still be used but may produce variable results.
  static Future<PreCheckResult> run() async {
    PreCheckStatus resStatus = PreCheckStatus.unavailable;
    String? resDetail;

    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();

      final w = controller.value.previewSize?.width ?? 0;
      final h = controller.value.previewSize?.height ?? 0;
      await controller.dispose();

      final maxDim = w > h ? w : h;
      final minDim = w < h ? w : h;

      if (maxDim >= _recommendedResolutionWidth &&
          minDim >= _recommendedResolutionHeight) {
        resStatus = PreCheckStatus.pass;
        resDetail = '${maxDim.toInt()}×${minDim.toInt()}';
      } else if (maxDim > 0 && minDim > 0) {
        // Camera available but below recommended resolution
        resStatus = PreCheckStatus.warning;
        resDetail =
            '${maxDim.toInt()}×${minDim.toInt()} — Below recommended 1920×1080. Results may vary.';
      } else {
        resStatus = PreCheckStatus.fail;
        resDetail = 'Could not determine camera resolution';
      }
    } catch (_) {
      resStatus = PreCheckStatus.unavailable;
      resDetail = 'Could not query camera';
    }

    return PreCheckResult(
      cameraResolution: resStatus,
      cameraResolutionDetail: resDetail,
    );
  }

  static double get minDistanceCm => _minDistanceCm;
  static double get maxDistanceCm => _maxDistanceCm;
}
