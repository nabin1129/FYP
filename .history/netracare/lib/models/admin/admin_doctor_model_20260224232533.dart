/// Admin Doctor Model
/// Represents a doctor managed by the admin
class AdminDoctor {
  final String id; // Manual ID given by admin
  final String name;
  final String email;
  final String password; // Password given by admin
  final String phone;
  final String specialization;
  final String nhpcNumber;
  final String qualification;
  final int experienceYears;
  final String workingPlace;
  final String address;
  double rating;
  bool isAvailable;
  bool isVerified;
  bool isActive;
  final String joinDate;
  int patients;
  int testsThisMonth;
  String avgResponseTime;

  AdminDoctor({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.phone,
    required this.specialization,
    required this.nhpcNumber,
    required this.qualification,
    required this.experienceYears,
    required this.workingPlace,
    required this.address,
    this.rating = 4.5,
    this.isAvailable = true,
    this.isVerified = true,
    this.isActive = true,
    required this.joinDate,
    this.patients = 0,
    this.testsThisMonth = 0,
    this.avgResponseTime = 'N/A',
  });

  String get status => isActive ? 'Active' : 'Inactive';

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  AdminDoctor copyWith({
    String? id,
    String? name,
    String? email,
    String? password,
    String? phone,
    String? specialization,
    String? nhpcNumber,
    String? qualification,
    int? experienceYears,
    String? workingPlace,
    String? address,
    double? rating,
    bool? isAvailable,
    bool? isVerified,
    bool? isActive,
    String? joinDate,
    int? patients,
    int? testsThisMonth,
    String? avgResponseTime,
  }) {
    return AdminDoctor(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      phone: phone ?? this.phone,
      specialization: specialization ?? this.specialization,
      nhpcNumber: nhpcNumber ?? this.nhpcNumber,
      qualification: qualification ?? this.qualification,
      experienceYears: experienceYears ?? this.experienceYears,
      workingPlace: workingPlace ?? this.workingPlace,
      address: address ?? this.address,
      rating: rating ?? this.rating,
      isAvailable: isAvailable ?? this.isAvailable,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      joinDate: joinDate ?? this.joinDate,
      patients: patients ?? this.patients,
      testsThisMonth: testsThisMonth ?? this.testsThisMonth,
      avgResponseTime: avgResponseTime ?? this.avgResponseTime,
    );
  }

  static List<AdminDoctor> getInitialDoctors() {
    return [
      AdminDoctor(
        id: 'DOC-001',
        name: 'Dr. Rajesh Kumar Shrestha',
        email: 'dr.rajesh.shrestha@netracare.np',
        password: 'doctor123',
        phone: '+977-9841234567',
        specialization: 'Ophthalmology',
        nhpcNumber: 'NHPC-12345',
        qualification: 'MBBS, MD (Ophthalmology)',
        experienceYears: 15,
        workingPlace: 'Tilganga Institute of Ophthalmology',
        address: 'Gaushala, Kathmandu',
        rating: 4.8,
        isAvailable: true,
        isVerified: true,
        isActive: true,
        joinDate: '1 Jan 2020',
        patients: 60,
        testsThisMonth: 45,
        avgResponseTime: '2 hours',
      ),
      AdminDoctor(
        id: 'DOC-002',
        name: 'Dr. Srijana Poudel',
        email: 'dr.srijana.poudel@netracare.np',
        password: 'doctor123',
        phone: '+977-9851234568',
        specialization: 'Ophthalmology',
        nhpcNumber: 'NHPC-23456',
        qualification: 'MBBS, MS (Ophthalmology)',
        experienceYears: 12,
        workingPlace: 'Nepal Eye Hospital',
        address: 'Tripureshwor, Kathmandu',
        rating: 4.9,
        isAvailable: true,
        isVerified: true,
        isActive: true,
        joinDate: '15 Mar 2020',
        patients: 48,
        testsThisMonth: 38,
        avgResponseTime: '3 hours',
      ),
      AdminDoctor(
        id: 'DOC-003',
        name: 'Dr. Bikash Thapa',
        email: 'dr.bikash.thapa@netracare.np',
        password: 'doctor123',
        phone: '+977-9861234569',
        specialization: 'Retinal Surgery',
        nhpcNumber: 'NHPC-34567',
        qualification: 'MBBS, MD (Ophthalmology)',
        experienceYears: 10,
        workingPlace: 'Lumbini Eye Institute',
        address: 'Bhairahawa, Rupandehi',
        rating: 4.7,
        isAvailable: true,
        isVerified: true,
        isActive: true,
        joinDate: '20 Jun 2020',
        patients: 52,
        testsThisMonth: 42,
        avgResponseTime: '1.5 hours',
      ),
      AdminDoctor(
        id: 'DOC-004',
        name: 'Dr. Anita Gurung',
        email: 'dr.anita.gurung@netracare.np',
        password: 'doctor123',
        phone: '+977-9841234570',
        specialization: 'Pediatric Ophthalmology',
        nhpcNumber: 'NHPC-45678',
        qualification: 'MBBS, MS (Ophthalmology)',
        experienceYears: 8,
        workingPlace: 'B.P. Koirala Lions Centre',
        address: 'Maharajgunj, Kathmandu',
        rating: 4.6,
        isAvailable: true,
        isVerified: true,
        isActive: true,
        joinDate: '1 Aug 2021',
        patients: 35,
        testsThisMonth: 28,
        avgResponseTime: '2.5 hours',
      ),
      AdminDoctor(
        id: 'DOC-005',
        name: 'Dr. Prakash Karki',
        email: 'dr.prakash.karki@netracare.np',
        password: 'doctor123',
        phone: '+977-9801234571',
        specialization: 'Glaucoma Specialist',
        nhpcNumber: 'NHPC-56789',
        qualification: 'MBBS, MD (Ophthalmology), Fellowship',
        experienceYears: 18,
        workingPlace: 'TU Teaching Hospital',
        address: 'Maharajgunj, Kathmandu',
        rating: 4.9,
        isAvailable: true,
        isVerified: true,
        isActive: true,
        joinDate: '10 Sep 2019',
        patients: 70,
        testsThisMonth: 55,
        avgResponseTime: '1 hour',
      ),
    ];
  }
}

const List<String> kSpecializations = [
  'Ophthalmology',
  'Optometry',
  'Retinal Surgery',
  'Pediatric Ophthalmology',
  'Glaucoma Specialist',
  'Cornea & Refractive',
  'Neuro-Ophthalmology',
];
