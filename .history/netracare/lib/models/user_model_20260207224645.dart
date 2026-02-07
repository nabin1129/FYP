/// User Model
/// Represents a user in the NetraCare application
class User {
  final int id;
  final String name;
  final String email;
  final int? age;
  final String? sex;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.age,
    this.sex,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      age: json['age'] as int?,
      sex: json['sex'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'age': age,
      'sex': sex,
    };
  }
}

/// Authentication Response
/// Returned from login and signup endpoints
class AuthResponse {
  final String token;
  final User user;

  AuthResponse({
    required this.token,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'user': user.toJson(),
    };
  }
}

/// Visual Acuity Test Result
/// Represents the result of a visual acuity test
class VisualAcuityResult {
  final int id;
  final int userId;
  final int correctAnswers;
  final int totalQuestions;
  final double logmarValue;
  final String snellenValue;
  final String severity;
  final DateTime createdAt;

  VisualAcuityResult({
    required this.id,
    required this.userId,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.logmarValue,
    required this.snellenValue,
    required this.severity,
    required this.createdAt,
  });

  /// Alias getters for convenience
  double get logMAR => logmarValue;
  String get snellen => snellenValue;

  factory VisualAcuityResult.fromJson(Map<String, dynamic> json) {
    return VisualAcuityResult(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      correctAnswers: json['correct_answers'] as int,
      totalQuestions: json['total_questions'] as int,
      logmarValue: (json['logmar_value'] as num).toDouble(),
      snellenValue: json['snellen_value'] as String,
      severity: json['severity'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'correct_answers': correctAnswers,
      'total_questions': totalQuestions,
      'logmar_value': logmarValue,
      'snellen_value': snellenValue,
      'severity': severity,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
