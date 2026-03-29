// Distance Calibration Model
// Stores baseline measurements for arm-length distance enforcement
// Author: NetraCare Team
// Date: January 26, 2026

/// Represents a user's calibration profile for distance enforcement
class DistanceCalibrationData {
  /// Unique calibration ID
  final String? calibrationId;

  /// User ID (linked to authenticated user)
  final String userId;

  /// Timestamp of calibration
  final DateTime calibratedAt;

  /// Reference distance in centimeters (typically 40-50 cm at arm's length)
  final double referenceDistance;

  /// Baseline interpupillary distance in pixels at reference distance
  final double baselineIpdPixels;

  /// Baseline face width in pixels at reference distance
  final double baselineFaceWidthPixels;

  /// Camera focal length estimate (calculated during calibration)
  final double focalLength;

  /// Average real-world IPD in centimeters (default: 6.3 cm)
  final double realWorldIpd;

  /// Tolerance range in centimeters (default: ±3 cm)
  final double toleranceCm;

  /// Device model/camera used for calibration
  final String? deviceModel;

  /// Camera resolution used (e.g., "1920x1080")
  final String? cameraResolution;

  /// Is this calibration currently active?
  final bool isActive;

  DistanceCalibrationData({
    this.calibrationId,
    required this.userId,
    required this.calibratedAt,
    required this.referenceDistance,
    required this.baselineIpdPixels,
    required this.baselineFaceWidthPixels,
    required this.focalLength,
    this.realWorldIpd = 6.3, // Average adult IPD
    this.toleranceCm = 3.0, // ±3 cm tolerance
    this.deviceModel,
    this.cameraResolution,
    this.isActive = true,
  });

  /// Create from JSON
  factory DistanceCalibrationData.fromJson(Map<String, dynamic> json) {
    return DistanceCalibrationData(
      calibrationId: json['calibration_id'] as String?,
      userId: json['user_id'] as String,
      calibratedAt: DateTime.parse(json['calibrated_at'] as String),
      referenceDistance: (json['reference_distance'] as num).toDouble(),
      baselineIpdPixels: (json['baseline_ipd_pixels'] as num).toDouble(),
      baselineFaceWidthPixels:
          (json['baseline_face_width_pixels'] as num).toDouble(),
      focalLength: (json['focal_length'] as num).toDouble(),
      realWorldIpd: (json['real_world_ipd'] as num?)?.toDouble() ?? 6.3,
      toleranceCm: (json['tolerance_cm'] as num?)?.toDouble() ?? 3.0,
      deviceModel: json['device_model'] as String?,
      cameraResolution: json['camera_resolution'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  /// Convert to JSON
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
    };
  }

  /// Create a copy with updated fields
  DistanceCalibrationData copyWith({
    String? calibrationId,
    String? userId,
    DateTime? calibratedAt,
    double? referenceDistance,
    double? baselineIpdPixels,
    double? baselineFaceWidthPixels,
    double? focalLength,
    double? realWorldIpd,
    double? toleranceCm,
    String? deviceModel,
    String? cameraResolution,
    bool? isActive,
  }) {
    return DistanceCalibrationData(
      calibrationId: calibrationId ?? this.calibrationId,
      userId: userId ?? this.userId,
      calibratedAt: calibratedAt ?? this.calibratedAt,
      referenceDistance: referenceDistance ?? this.referenceDistance,
      baselineIpdPixels: baselineIpdPixels ?? this.baselineIpdPixels,
      baselineFaceWidthPixels:
          baselineFaceWidthPixels ?? this.baselineFaceWidthPixels,
      focalLength: focalLength ?? this.focalLength,
      realWorldIpd: realWorldIpd ?? this.realWorldIpd,
      toleranceCm: toleranceCm ?? this.toleranceCm,
      deviceModel: deviceModel ?? this.deviceModel,
      cameraResolution: cameraResolution ?? this.cameraResolution,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'DistanceCalibrationData(userId: $userId, refDist: ${referenceDistance}cm, '
        'ipdPixels: $baselineIpdPixels, focalLength: $focalLength)';
  }
}

/// Represents real-time distance validation result
class DistanceValidationResult {
  /// Current measured distance in centimeters
  final double currentDistance;

  /// Reference/target distance in centimeters
  final double referenceDistance;

  /// Difference from reference (currentDistance - referenceDistance)
  final double delta;

  /// Is the distance within acceptable tolerance?
  final bool isValid;

  /// Tolerance used for validation (in cm)
  final double toleranceCm;

  /// Validation status message
  final DistanceStatus status;

  /// Detected face IPD in pixels (for debugging)
  final double? detectedIpdPixels;

  /// Timestamp of measurement
  final DateTime timestamp;

  DistanceValidationResult({
    required this.currentDistance,
    required this.referenceDistance,
    required this.delta,
    required this.isValid,
    required this.toleranceCm,
    required this.status,
    this.detectedIpdPixels,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Feedback message for user
  String get feedbackMessage {
    switch (status) {
      case DistanceStatus.perfect:
        return 'Perfect distance!';
      case DistanceStatus.tooClose:
        return 'Move back ${delta.abs().toStringAsFixed(1)} cm';
      case DistanceStatus.tooFar:
        return 'Move closer ${delta.abs().toStringAsFixed(1)} cm';
      case DistanceStatus.acceptable:
        return 'Good position';
      case DistanceStatus.noFaceDetected:
        return 'No face detected';
      case DistanceStatus.multipleFaces:
        return 'Multiple faces detected';
      case DistanceStatus.error:
        return 'Distance measurement error';
    }
  }

  @override
  String toString() {
    return 'DistanceValidation(current: ${currentDistance.toStringAsFixed(1)}cm, '
        'ref: ${referenceDistance.toStringAsFixed(1)}cm, '
        'delta: ${delta.toStringAsFixed(1)}cm, valid: $isValid)';
  }
}

/// Distance validation status
enum DistanceStatus {
  /// Distance is perfect (within ±1 cm)
  perfect,

  /// Distance is acceptable (within tolerance, but not perfect)
  acceptable,

  /// User is too close to camera
  tooClose,

  /// User is too far from camera
  tooFar,

  /// No face detected in frame
  noFaceDetected,

  /// Multiple faces detected (should be only one)
  multipleFaces,

  /// Error during distance measurement
  error,
}

/// Extension for status color mapping
extension DistanceStatusExtension on DistanceStatus {
  /// Get color for UI feedback
  int get colorValue {
    switch (this) {
      case DistanceStatus.perfect:
        return 0xFF00C853; // Bright green
      case DistanceStatus.acceptable:
        return 0xFF64DD17; // Light green
      case DistanceStatus.tooClose:
      case DistanceStatus.tooFar:
        return 0xFFFF6D00; // Orange
      case DistanceStatus.noFaceDetected:
      case DistanceStatus.multipleFaces:
      case DistanceStatus.error:
        return 0xFFD50000; // Red
    }
  }

  /// Should the test be paused for this status?
  bool get shouldPauseTest {
    switch (this) {
      case DistanceStatus.perfect:
      case DistanceStatus.acceptable:
        return false;
      case DistanceStatus.tooClose:
      case DistanceStatus.tooFar:
      case DistanceStatus.noFaceDetected:
      case DistanceStatus.multipleFaces:
      case DistanceStatus.error:
        return true;
    }
  }
}
