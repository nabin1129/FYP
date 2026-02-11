/// Test Type Enumeration
///
/// Defines all available eye test types in the NetraCare application.
enum TestType {
  visualAcuity,
  colorBlindness,
  astigmatism,
  contrastSensitivity,
  eyeTracking,
  pupilResponse,
  fatigue;

  /// Get display name for the test type
  String get displayName {
    switch (this) {
      case TestType.visualAcuity:
        return 'Visual Acuity Test';
      case TestType.colorBlindness:
        return 'Color Blindness Test';
      case TestType.astigmatism:
        return 'Astigmatism Test';
      case TestType.contrastSensitivity:
        return 'Contrast Sensitivity Test';
      case TestType.eyeTracking:
        return 'Eye Tracking Test';
      case TestType.pupilResponse:
        return 'Pupil Response Test';
      case TestType.fatigue:
        return 'Eye Fatigue Test';
    }
  }

  /// Get description for the test type
  String get description {
    switch (this) {
      case TestType.visualAcuity:
        return 'Measure clarity and sharpness of vision';
      case TestType.colorBlindness:
        return 'Detect color vision deficiencies';
      case TestType.astigmatism:
        return 'Check for irregular eye curvature';
      case TestType.contrastSensitivity:
        return 'Measure ability to distinguish contrasts';
      case TestType.eyeTracking:
        return 'Assess eye movement patterns';
      case TestType.pupilResponse:
        return 'Evaluate pupil reaction to light';
      case TestType.fatigue:
        return 'Detect signs of eye strain and fatigue';
    }
  }

  /// Get icon for the test type
  String get iconName {
    switch (this) {
      case TestType.visualAcuity:
        return 'remove_red_eye';
      case TestType.colorBlindness:
        return 'palette';
      case TestType.astigmatism:
        return 'visibility';
      case TestType.contrastSensitivity:
        return 'contrast';
      case TestType.eyeTracking:
        return 'track_changes';
      case TestType.pupilResponse:
        return 'light_mode';
      case TestType.fatigue:
        return 'timer';
    }
  }
}

/// Test Result Model
///
/// Generic model to store test results from any test type.
class TestResult {
  final TestType testType;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  final double? score;
  final String? diagnosis;
  final List<String>? recommendations;

  TestResult({
    required this.testType,
    required this.timestamp,
    required this.data,
    this.score,
    this.diagnosis,
    this.recommendations,
  });

  Map<String, dynamic> toJson() {
    return {
      'testType': testType.name,
      'timestamp': timestamp.toIso8601String(),
      'data': data,
      'score': score,
      'diagnosis': diagnosis,
      'recommendations': recommendations,
    };
  }

  factory TestResult.fromJson(Map<String, dynamic> json) {
    return TestResult(
      testType: TestType.values.firstWhere(
        (e) => e.name == json['testType'],
        orElse: () => TestType.visualAcuity,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      data: json['data'] as Map<String, dynamic>,
      score: json['score'] as double?,
      diagnosis: json['diagnosis'] as String?,
      recommendations: (json['recommendations'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }
}
