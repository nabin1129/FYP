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
      name: json['name'] as String? ?? '',
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
}
