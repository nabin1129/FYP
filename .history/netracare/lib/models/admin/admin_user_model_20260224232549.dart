/// Admin User Model
/// Represents a user/patient as seen by the admin
class AdminUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final int age;
  final String gender;
  final String location;
  final String lastTest;
  final int totalTests;
  final int healthScore;
  bool isActive;
  final String joinDate;
  final String nextAppointment;

  AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.age,
    required this.gender,
    required this.location,
    required this.lastTest,
    required this.totalTests,
    required this.healthScore,
    this.isActive = true,
    required this.joinDate,
    required this.nextAppointment,
  });

  String get status => isActive ? 'Active' : 'Inactive';

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get healthLabel {
    if (healthScore >= 80) return 'Excellent';
    if (healthScore >= 60) return 'Good';
    return 'Needs Attention';
  }

  AdminUser copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    int? age,
    String? gender,
    String? location,
    String? lastTest,
    int? totalTests,
    int? healthScore,
    bool? isActive,
    String? joinDate,
    String? nextAppointment,
  }) {
    return AdminUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      location: location ?? this.location,
      lastTest: lastTest ?? this.lastTest,
      totalTests: totalTests ?? this.totalTests,
      healthScore: healthScore ?? this.healthScore,
      isActive: isActive ?? this.isActive,
      joinDate: joinDate ?? this.joinDate,
      nextAppointment: nextAppointment ?? this.nextAppointment,
    );
  }

  static List<AdminUser> getInitialUsers() {
    return [
      AdminUser(
        id: 'USR-001',
        name: 'Aarav Sharma',
        email: 'aarav.sharma@example.com',
        phone: '+977-9801112233',
        age: 32,
        gender: 'Male',
        location: 'Kathmandu, Nepal',
        lastTest: '2 days ago',
        totalTests: 12,
        healthScore: 85,
        isActive: true,
        joinDate: '15 Jan 2024',
        nextAppointment: '20 Jun 2025',
      ),
      AdminUser(
        id: 'USR-002',
        name: 'Priya Thapa',
        email: 'priya.thapa@example.com',
        phone: '+977-9812223344',
        age: 45,
        gender: 'Female',
        location: 'Pokhara, Nepal',
        lastTest: '1 week ago',
        totalTests: 8,
        healthScore: 72,
        isActive: true,
        joinDate: '20 Feb 2024',
        nextAppointment: '25 Jun 2025',
      ),
      AdminUser(
        id: 'USR-003',
        name: 'Bikram Rai',
        email: 'bikram.rai@example.com',
        phone: '+977-9823334455',
        age: 28,
        gender: 'Male',
        location: 'Biratnagar, Nepal',
        lastTest: '3 days ago',
        totalTests: 15,
        healthScore: 90,
        isActive: true,
        joinDate: '10 Mar 2024',
        nextAppointment: '18 Jun 2025',
      ),
      AdminUser(
        id: 'USR-004',
        name: 'Sunita Gurung',
        email: 'sunita.gurung@example.com',
        phone: '+977-9834445566',
        age: 55,
        gender: 'Female',
        location: 'Lalitpur, Nepal',
        lastTest: '2 weeks ago',
        totalTests: 6,
        healthScore: 68,
        isActive: false,
        joinDate: '5 Apr 2024',
        nextAppointment: 'Not scheduled',
      ),
      AdminUser(
        id: 'USR-005',
        name: 'Manish Karki',
        email: 'manish.karki@example.com',
        phone: '+977-9845556677',
        age: 38,
        gender: 'Male',
        location: 'Bhaktapur, Nepal',
        lastTest: '5 days ago',
        totalTests: 20,
        healthScore: 78,
        isActive: true,
        joinDate: '12 May 2024',
        nextAppointment: '30 Jun 2025',
      ),
    ];
  }
}
