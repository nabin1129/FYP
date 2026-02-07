/// Distance Status Enum
/// Represents the current distance validation status
enum DistanceStatus {
  perfect,
  acceptable,
  tooClose,
  tooFar,
  noFaceDetected,
  multipleFaces,
  error;

  /// Whether the test should be paused based on this status
  bool get shouldPauseTest {
    return this == DistanceStatus.tooClose ||
        this == DistanceStatus.tooFar ||
        this == DistanceStatus.noFaceDetected ||
        this == DistanceStatus.multipleFaces ||
        this == DistanceStatus.error;
  }

  /// Get human-readable message for this status
  String get message {
    switch (this) {
      case DistanceStatus.perfect:
        return 'Perfect distance! You are at the optimal position.';
      case DistanceStatus.acceptable:
        return 'Good distance. You are within acceptable range.';
      case DistanceStatus.tooClose:
        return 'Too close! Please move back a bit.';
      case DistanceStatus.tooFar:
        return 'Too far! Please move closer.';
      case DistanceStatus.noFaceDetected:
        return 'No face detected. Please position yourself in front of the camera.';
      case DistanceStatus.multipleFaces:
        return 'Multiple faces detected. Please ensure only one person is in frame.';
      case DistanceStatus.error:
        return 'Error in distance detection. Please try again.';
    }
  }
}

/// Distance Calibration Data
/// Contains calibration measurements for distance enforcement
class DistanceCalibrationData {
  final int calibrationId;
  final int userId;
  final DateTime calibratedAt;
  final double referenceDistance;
  final double baselineIpdPixels;
  final double baselineFaceWidthPixels;
  final double focalLength;
  final double realWorldIpd;
  final double toleranceCm;
  final String? deviceModel;
  final String? cameraResolution;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  DistanceCalibrationData({
    required this.calibrationId,
    required this.userId,
    required this.calibratedAt,
    required this.referenceDistance,
    required this.baselineIpdPixels,
    required this.baselineFaceWidthPixels,
    required this.focalLength,
    required this.realWorldIpd,
    required this.toleranceCm,
    this.deviceModel,
    this.cameraResolution,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DistanceCalibrationData.fromJson(Map<String, dynamic> json) {
    return DistanceCalibrationData(
      calibrationId: json['calibration_id'] as int,
      userId: json['user_id'] as int,
      calibratedAt: DateTime.parse(json['calibrated_at'] as String),
      referenceDistance: (json['reference_distance'] as num).toDouble(),
      baselineIpdPixels: (json['baseline_ipd_pixels'] as num).toDouble(),
      baselineFaceWidthPixels:
          (json['baseline_face_width_pixels'] as num).toDouble(),
      focalLength: (json['focal_length'] as num).toDouble(),
      realWorldIpd: (json['real_world_ipd'] as num).toDouble(),
      toleranceCm: (json['tolerance_cm'] as num).toDouble(),
      deviceModel: json['device_model'] as String?,
      cameraResolution: json['camera_resolution'] as String?,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calibration_id': calibrationId,
      'user_id': userId,
      'calibrated_at': calibratedAt.toIso8601String(),
      'reference_distance': referenceDistance,
      'baseline_ipd_pixels': baselineIpdPixels,
      'baseline_face_width_pixels': baselineFaceWidthPixels,
      'focal_length': focalLength,
      'real_world_ipd': realWorldIpd,
      'tolerance_cm': toleranceCm,
      'device_model': deviceModel,
      'camera_resolution': cameraResolution,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Distance Validation Result
/// Contains the result of distance validation during tests
class DistanceValidationResult {
  final double currentDistance;
  final double referenceDistance;
  final double delta;
  final bool isValid;
  final double toleranceCm;
  final DistanceStatus status;
  final double? detectedIpdPixels;

  DistanceValidationResult({
    required this.currentDistance,
    required this.referenceDistance,
    required this.delta,
    required this.isValid,
    required this.toleranceCm,
    required this.status,
    this.detectedIpdPixels,
  });

  /// Get the deviation percentage from reference
  double get deviationPercentage {
    if (referenceDistance == 0) return 0;
    return (delta.abs() / referenceDistance) * 100;
  }

  /// Get a progress value between 0-1 based on distance accuracy
  double get accuracyProgress {
    if (!isValid) return 0;
    final deviation = delta.abs();
    if (deviation <= 1.0) return 1.0; // Perfect
    if (deviation <= toleranceCm) {
      return 1.0 - (deviation - 1.0) / (toleranceCm - 1.0) * 0.3;
    }
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'current_distance': currentDistance,
      'reference_distance': referenceDistance,
      'delta': delta,
      'is_valid': isValid,
      'tolerance_cm': toleranceCm,
      'status': status.name,
      'detected_ipd_pixels': detectedIpdPixels,
    };
  }

  factory DistanceValidationResult.fromJson(Map<String, dynamic> json) {
    return DistanceValidationResult(
      currentDistance: (json['current_distance'] as num).toDouble(),
      referenceDistance: (json['reference_distance'] as num).toDouble(),
      delta: (json['delta'] as num).toDouble(),
      isValid: json['is_valid'] as bool,
      toleranceCm: (json['tolerance_cm'] as num).toDouble(),
      status: DistanceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DistanceStatus.error,
      ),
      detectedIpdPixels: json['detected_ipd_pixels'] != null
          ? (json['detected_ipd_pixels'] as num).toDouble()
          : null,
    );
  }
}
