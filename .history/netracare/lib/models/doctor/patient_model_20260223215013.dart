/// Patient Model for Doctor Dashboard
/// Represents a patient with their health data and test results

class Patient {
  final String id;
  final String name;
  final String email;
  final int? age;
  final String? sex;
  final String? phone;
  final String? address;
  final int healthScore;
  final String trend; // 'up', 'down', 'stable'
  final HealthStatus status;
  final DateTime? lastTestDate;
  final String? profileImageUrl;
  final PatientTestSummary? testSummary;

  Patient({
    required this.id,
    required this.name,
    required this.email,
    this.age,
    this.sex,
    this.phone,
    this.address,
    required this.healthScore,
    required this.trend,
    required this.status,
    this.lastTestDate,
    this.profileImageUrl,
    this.testSummary,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      age: json['age'] as int?,
      sex: json['sex'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      healthScore: json['healthScore'] as int? ?? 0,
      trend: json['trend'] as String? ?? 'stable',
      status: HealthStatus.fromString(json['status'] as String? ?? 'good'),
      lastTestDate: json['lastTestDate'] != null
          ? DateTime.parse(json['lastTestDate'] as String)
          : null,
      profileImageUrl: json['profileImageUrl'] as String?,
      testSummary: json['testSummary'] != null
          ? PatientTestSummary.fromJson(
              json['testSummary'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'age': age,
      'sex': sex,
      'phone': phone,
      'address': address,
      'healthScore': healthScore,
      'trend': trend,
      'status': status.toString(),
      'lastTestDate': lastTestDate?.toIso8601String(),
      'profileImageUrl': profileImageUrl,
      'testSummary': testSummary?.toJson(),
    };
  }

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get lastTestAgo {
    if (lastTestDate == null) return 'No tests';
    final diff = DateTime.now().difference(lastTestDate!);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return '1 day ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    return '${(diff.inDays / 30).floor()} months ago';
  }

  // Mock patients for development
  static List<Patient> getMockPatients() {
    return [
      Patient(
        id: '1',
        name: 'Sarah Johnson',
        email: 'sarah.johnson@email.com',
        age: 32,
        sex: 'Female',
        phone: '+977-9841234567',
        healthScore: 85,
        trend: 'up',
        status: HealthStatus.good,
        lastTestDate: DateTime.now().subtract(const Duration(days: 2)),
        testSummary: PatientTestSummary(
          visualAcuityScore: '6/6',
          blinkRate: 18,
          fatigueLevel: 'Low',
          colourVisionStatus: 'Normal',
          pupilReflexStatus: 'Normal',
          testsCompleted: 4,
          totalTests: 5,
        ),
      ),
      Patient(
        id: '2',
        name: 'Michael Brown',
        email: 'michael.brown@email.com',
        age: 45,
        sex: 'Male',
        phone: '+977-9851234567',
        healthScore: 72,
        trend: 'down',
        status: HealthStatus.attention,
        lastTestDate: DateTime.now().subtract(const Duration(days: 7)),
        testSummary: PatientTestSummary(
          visualAcuityScore: '6/12',
          blinkRate: 12,
          fatigueLevel: 'Moderate',
          colourVisionStatus: 'Mild Deficiency',
          pupilReflexStatus: 'Normal',
          testsCompleted: 5,
          totalTests: 5,
        ),
      ),
      Patient(
        id: '3',
        name: 'Emily Davis',
        email: 'emily.davis@email.com',
        age: 28,
        sex: 'Female',
        phone: '+977-9861234567',
        healthScore: 90,
        trend: 'up',
        status: HealthStatus.good,
        lastTestDate: DateTime.now().subtract(const Duration(days: 3)),
        testSummary: PatientTestSummary(
          visualAcuityScore: '6/6',
          blinkRate: 20,
          fatigueLevel: 'Low',
          colourVisionStatus: 'Normal',
          pupilReflexStatus: 'Normal',
          testsCompleted: 5,
          totalTests: 5,
        ),
      ),
      Patient(
        id: '4',
        name: 'James Wilson',
        email: 'james.wilson@email.com',
        age: 55,
        sex: 'Male',
        phone: '+977-9871234567',
        healthScore: 68,
        trend: 'down',
        status: HealthStatus.critical,
        lastTestDate: DateTime.now().subtract(const Duration(days: 5)),
        testSummary: PatientTestSummary(
          visualAcuityScore: '6/18',
          blinkRate: 10,
          fatigueLevel: 'High',
          colourVisionStatus: 'Moderate Deficiency',
          pupilReflexStatus: 'Slow Response',
          testsCompleted: 5,
          totalTests: 5,
        ),
      ),
      Patient(
        id: '5',
        name: 'Lisa Anderson',
        email: 'lisa.anderson@email.com',
        age: 38,
        sex: 'Female',
        phone: '+977-9881234567',
        healthScore: 88,
        trend: 'up',
        status: HealthStatus.good,
        lastTestDate: DateTime.now().subtract(const Duration(days: 1)),
        testSummary: PatientTestSummary(
          visualAcuityScore: '6/9',
          blinkRate: 17,
          fatigueLevel: 'Low',
          colourVisionStatus: 'Normal',
          pupilReflexStatus: 'Normal',
          testsCompleted: 3,
          totalTests: 5,
        ),
      ),
      Patient(
        id: '6',
        name: 'Robert Taylor',
        email: 'robert.taylor@email.com',
        age: 62,
        sex: 'Male',
        phone: '+977-9891234567',
        healthScore: 75,
        trend: 'stable',
        status: HealthStatus.attention,
        lastTestDate: DateTime.now().subtract(const Duration(days: 10)),
        testSummary: PatientTestSummary(
          visualAcuityScore: '6/12',
          blinkRate: 14,
          fatigueLevel: 'Moderate',
          colourVisionStatus: 'Normal',
          pupilReflexStatus: 'Normal',
          testsCompleted: 4,
          totalTests: 5,
        ),
      ),
    ];
  }
}

/// Test summary for a patient
class PatientTestSummary {
  final String? visualAcuityScore;
  final int? blinkRate;
  final String? fatigueLevel;
  final String? colourVisionStatus;
  final String? pupilReflexStatus;
  final int testsCompleted;
  final int totalTests;

  PatientTestSummary({
    this.visualAcuityScore,
    this.blinkRate,
    this.fatigueLevel,
    this.colourVisionStatus,
    this.pupilReflexStatus,
    required this.testsCompleted,
    required this.totalTests,
  });

  factory PatientTestSummary.fromJson(Map<String, dynamic> json) {
    return PatientTestSummary(
      visualAcuityScore: json['visualAcuityScore'] as String?,
      blinkRate: json['blinkRate'] as int?,
      fatigueLevel: json['fatigueLevel'] as String?,
      colourVisionStatus: json['colourVisionStatus'] as String?,
      pupilReflexStatus: json['pupilReflexStatus'] as String?,
      testsCompleted: json['testsCompleted'] as int? ?? 0,
      totalTests: json['totalTests'] as int? ?? 5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'visualAcuityScore': visualAcuityScore,
      'blinkRate': blinkRate,
      'fatigueLevel': fatigueLevel,
      'colourVisionStatus': colourVisionStatus,
      'pupilReflexStatus': pupilReflexStatus,
      'testsCompleted': testsCompleted,
      'totalTests': totalTests,
    };
  }
}

/// Health status enum
enum HealthStatus {
  good,
  attention,
  critical;

  static HealthStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'good':
        return HealthStatus.good;
      case 'attention':
        return HealthStatus.attention;
      case 'critical':
        return HealthStatus.critical;
      default:
        return HealthStatus.good;
    }
  }

  @override
  String toString() {
    switch (this) {
      case HealthStatus.good:
        return 'Good';
      case HealthStatus.attention:
        return 'Attention';
      case HealthStatus.critical:
        return 'Critical';
    }
  }

  String get label {
    switch (this) {
      case HealthStatus.good:
        return 'Good';
      case HealthStatus.attention:
        return 'Needs Attention';
      case HealthStatus.critical:
        return 'Critical';
    }
  }
}
