/// Doctor Analytics Model
/// Represents statistics and analytics data for the doctor dashboard

class DoctorAnalytics {
  final int totalPatients;
  final int newPatientsThisMonth;
  final double averageHealthScore;
  final double healthScoreChange;
  final int testsThisWeek;
  final int pendingReviews;
  final PatientDistribution distribution;
  final List<HealthTrendData> healthTrend;
  final List<TestTypeStats> testStats;

  DoctorAnalytics({
    required this.totalPatients,
    required this.newPatientsThisMonth,
    required this.averageHealthScore,
    required this.healthScoreChange,
    required this.testsThisWeek,
    required this.pendingReviews,
    required this.distribution,
    required this.healthTrend,
    required this.testStats,
  });

  factory DoctorAnalytics.fromJson(Map<String, dynamic> json) {
    return DoctorAnalytics(
      totalPatients: json['totalPatients'] as int,
      newPatientsThisMonth: json['newPatientsThisMonth'] as int,
      averageHealthScore: (json['averageHealthScore'] as num).toDouble(),
      healthScoreChange: (json['healthScoreChange'] as num).toDouble(),
      testsThisWeek: json['testsThisWeek'] as int,
      pendingReviews: json['pendingReviews'] as int,
      distribution: PatientDistribution.fromJson(
          json['distribution'] as Map<String, dynamic>),
      healthTrend: (json['healthTrend'] as List)
          .map((e) => HealthTrendData.fromJson(e as Map<String, dynamic>))
          .toList(),
      testStats: (json['testStats'] as List)
          .map((e) => TestTypeStats.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalPatients': totalPatients,
      'newPatientsThisMonth': newPatientsThisMonth,
      'averageHealthScore': averageHealthScore,
      'healthScoreChange': healthScoreChange,
      'testsThisWeek': testsThisWeek,
      'pendingReviews': pendingReviews,
      'distribution': distribution.toJson(),
      'healthTrend': healthTrend.map((e) => e.toJson()).toList(),
      'testStats': testStats.map((e) => e.toJson()).toList(),
    };
  }

  // Mock analytics data
  static DoctorAnalytics getMockAnalytics() {
    return DoctorAnalytics(
      totalPatients: 60,
      newPatientsThisMonth: 5,
      averageHealthScore: 86,
      healthScoreChange: 2.5,
      testsThisWeek: 12,
      pendingReviews: 3,
      distribution: PatientDistribution(
        good: 45,
        attention: 12,
        critical: 3,
      ),
      healthTrend: [
        HealthTrendData(month: 'Jan', avgScore: 78),
        HealthTrendData(month: 'Feb', avgScore: 82),
        HealthTrendData(month: 'Mar', avgScore: 79),
        HealthTrendData(month: 'Apr', avgScore: 84),
        HealthTrendData(month: 'May', avgScore: 86),
        HealthTrendData(month: 'Jun', avgScore: 88),
      ],
      testStats: [
        TestTypeStats(testType: 'Visual Acuity', count: 45, avgScore: 82),
        TestTypeStats(testType: 'Eye Tracking', count: 38, avgScore: 78),
        TestTypeStats(testType: 'Blink & Fatigue', count: 42, avgScore: 85),
        TestTypeStats(testType: 'Pupil Reflex', count: 35, avgScore: 88),
        TestTypeStats(testType: 'Colour Vision', count: 40, avgScore: 90),
      ],
    );
  }
}

/// Patient distribution by health status
class PatientDistribution {
  final int good;
  final int attention;
  final int critical;

  PatientDistribution({
    required this.good,
    required this.attention,
    required this.critical,
  });

  factory PatientDistribution.fromJson(Map<String, dynamic> json) {
    return PatientDistribution(
      good: json['good'] as int,
      attention: json['attention'] as int,
      critical: json['critical'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'good': good,
      'attention': attention,
      'critical': critical,
    };
  }

  int get total => good + attention + critical;

  double get goodPercentage => total > 0 ? (good / total) * 100 : 0;
  double get attentionPercentage => total > 0 ? (attention / total) * 100 : 0;
  double get criticalPercentage => total > 0 ? (critical / total) * 100 : 0;
}

/// Health trend data point
class HealthTrendData {
  final String month;
  final double avgScore;

  HealthTrendData({
    required this.month,
    required this.avgScore,
  });

  factory HealthTrendData.fromJson(Map<String, dynamic> json) {
    return HealthTrendData(
      month: json['month'] as String,
      avgScore: (json['avgScore'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'avgScore': avgScore,
    };
  }
}

/// Test type statistics
class TestTypeStats {
  final String testType;
  final int count;
  final double avgScore;

  TestTypeStats({
    required this.testType,
    required this.count,
    required this.avgScore,
  });

  factory TestTypeStats.fromJson(Map<String, dynamic> json) {
    return TestTypeStats(
      testType: json['testType'] as String,
      count: json['count'] as int,
      avgScore: (json['avgScore'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'testType': testType,
      'count': count,
      'avgScore': avgScore,
    };
  }
}

/// Doctor consultation request from patient
class ConsultationRequest {
  final String id;
  final String patientId;
  final String patientName;
  final String? patientImageUrl;
  final String requestType; // 'video_call' or 'chat'
  final DateTime requestedAt;
  final String? message;
  final RequestStatus status;

  ConsultationRequest({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.patientImageUrl,
    required this.requestType,
    required this.requestedAt,
    this.message,
    required this.status,
  });

  factory ConsultationRequest.fromJson(Map<String, dynamic> json) {
    return ConsultationRequest(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      patientName: json['patientName'] as String,
      patientImageUrl: json['patientImageUrl'] as String?,
      requestType: json['requestType'] as String,
      requestedAt: DateTime.parse(json['requestedAt'] as String),
      message: json['message'] as String?,
      status: RequestStatus.fromString(json['status'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'patientImageUrl': patientImageUrl,
      'requestType': requestType,
      'requestedAt': requestedAt.toIso8601String(),
      'message': message,
      'status': status.key,
    };
  }

  String get initials {
    final parts = patientName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return patientName.isNotEmpty ? patientName[0].toUpperCase() : '?';
  }

  String get requestedAgo {
    final diff = DateTime.now().difference(requestedAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  // Mock consultation requests
  static List<ConsultationRequest> getMockRequests() {
    return [
      ConsultationRequest(
        id: 'req_1',
        patientId: '1',
        patientName: 'Sarah Johnson',
        requestType: 'video_call',
        requestedAt: DateTime.now().subtract(const Duration(hours: 2)),
        message: 'I would like to discuss my recent test results.',
        status: RequestStatus.pending,
      ),
      ConsultationRequest(
        id: 'req_2',
        patientId: '2',
        patientName: 'Michael Brown',
        requestType: 'chat',
        requestedAt: DateTime.now().subtract(const Duration(hours: 5)),
        message: 'Need advice on my eye fatigue symptoms.',
        status: RequestStatus.pending,
      ),
      ConsultationRequest(
        id: 'req_3',
        patientId: '3',
        patientName: 'Emily Davis',
        requestType: 'video_call',
        requestedAt: DateTime.now().subtract(const Duration(days: 1)),
        message: 'Follow-up consultation as scheduled.',
        status: RequestStatus.accepted,
      ),
    ];
  }
}

/// Request status enum
enum RequestStatus {
  pending,
  accepted,
  rejected,
  completed;

  static RequestStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return RequestStatus.pending;
      case 'accepted':
        return RequestStatus.accepted;
      case 'rejected':
        return RequestStatus.rejected;
      case 'completed':
        return RequestStatus.completed;
      default:
        return RequestStatus.pending;
    }
  }

  @override
  String toString() {
    switch (this) {
      case RequestStatus.pending:
        return 'Pending';
      case RequestStatus.accepted:
        return 'Accepted';
      case RequestStatus.rejected:
        return 'Rejected';
      case RequestStatus.completed:
        return 'Completed';
    }
  }

  String get key {
    switch (this) {
      case RequestStatus.pending:
        return 'pending';
      case RequestStatus.accepted:
        return 'accepted';
      case RequestStatus.rejected:
        return 'rejected';
      case RequestStatus.completed:
        return 'completed';
    }
  }
}
