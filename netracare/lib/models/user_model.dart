class User {
  final int id;
  final String name;
  final String email;
  final int? age;
  final String? sex;
  final String? phone;
  final String? address;
  final String? emergencyContact;
  final String? medicalHistory;
  final String? profileImageUrl;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.age,
    this.sex,
    this.phone,
    this.address,
    this.emergencyContact,
    this.medicalHistory,
    this.profileImageUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      email: json['email'] as String,
      age: json['age'] as int?,
      sex: json['sex'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      emergencyContact:
          (json['emergency_contact'] ?? json['emergencyContact']) as String?,
      medicalHistory:
          (json['medical_history'] ?? json['medicalHistory']) as String?,
      profileImageUrl:
          (json['profile_image_url'] ?? json['profileImageUrl']) as String?,
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
      'emergency_contact': emergencyContact,
      'medical_history': medicalHistory,
      'profile_image_url': profileImageUrl,
    };
  }
}

class AuthResponse {
  final String token;
  final User user;

  AuthResponse({required this.token, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class VisualAcuityResult {
  final double logMAR;
  final String snellen;
  final String severity;

  VisualAcuityResult({
    required this.logMAR,
    required this.snellen,
    required this.severity,
  });

  factory VisualAcuityResult.fromJson(Map<String, dynamic> json) {
    return VisualAcuityResult(
      logMAR: (json['logmar_value'] as num?)?.toDouble() ?? 0.0,
      snellen: json['snellen_value'] as String? ?? 'Unknown',
      severity: json['severity'] as String? ?? 'Unknown',
    );
  }
}
