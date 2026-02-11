/// Model for Doctor information
class Doctor {
  final String id;
  final String name;
  final String specialization;
  final String experience;
  final double rating;
  final String availability;
  final String nextSlot;
  final String image;
  final String nmcNumber; // Nepal Medical Council number
  final String workingPlace; // Hospital/Clinic name
  final String contactPhone;
  final String contactEmail;
  final String qualification; // MBBS, MD/MS Ophthalmology, etc.
  final String? address; // Optional clinic address

  Doctor({
    required this.id,
    required this.name,
    required this.specialization,
    required this.experience,
    required this.rating,
    required this.availability,
    required this.nextSlot,
    required this.image,
    required this.nmcNumber,
    required this.workingPlace,
    required this.contactPhone,
    required this.contactEmail,
    required this.qualification,
    this.address,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['id'] as String,
      name: json['name'] as String,
      specialization: json['specialization'] as String,
      experience: json['experience'] as String,
      rating: (json['rating'] as num).toDouble(),
      availability: json['availability'] as String,
      nextSlot: json['nextSlot'] as String,
      image: json['image'] as String,
      nmcNumber: json['nmcNumber'] as String,
      workingPlace: json['workingPlace'] as String,
      contactPhone: json['contactPhone'] as String,
      contactEmail: json['contactEmail'] as String,
      qualification: json['qualification'] as String,
      address: json['address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'specialization': specialization,
      'experience': experience,
      'rating': rating,
      'availability': availability,
      'nextSlot': nextSlot,
      'image': image,
      'nmcNumber': nmcNumber,
      'workingPlace': workingPlace,
      'contactPhone': contactPhone,
      'contactEmail': contactEmail,
      'qualification': qualification,
      if (address != null) 'address': address,
    };
  }

  // Static method to get mock doctors data (Nepali doctors)
  static List<Doctor> getMockDoctors() {
    return [
      Doctor(
        id: '1',
        name: 'Dr. Rajesh Kumar Shrestha',
        specialization: 'Ophthalmology',
        qualification: 'MBBS, MD (Ophthalmology)',
        experience: '15 years',
        rating: 4.8,
        availability: 'Available Today',
        nextSlot: '2:00 PM',
        image: 'https://i.pravatar.cc/150?img=12',
        nmcNumber: 'NMC-12345',
        workingPlace: 'Tilganga Institute of Ophthalmology',
        contactPhone: '+977-9841234567',
        contactEmail: 'dr.rajesh.shrestha@gmail.com',
        address: 'Gaushala, Kathmandu',
      ),
      Doctor(
        id: '2',
        name: 'Dr. Srijana Poudel',
        specialization: 'Ophthalmology',
        qualification: 'MBBS, MS (Ophthalmology)',
        experience: '12 years',
        rating: 4.9,
        availability: 'Available Tomorrow',
        nextSlot: '10:00 AM',
        image: 'https://i.pravatar.cc/150?img=45',
        nmcNumber: 'NMC-23456',
        workingPlace: 'Nepal Eye Hospital',
        contactPhone: '+977-9851234568',
        contactEmail: 'dr.srijana.poudel@gmail.com',
        address: 'Tripureshwor, Kathmandu',
      ),
      Doctor(
        id: '3',
        name: 'Dr. Bikash Thapa',
        specialization: 'Ophthalmology',
        qualification: 'MBBS, MD (Ophthalmology)',
        experience: '10 years',
        rating: 4.7,
        availability: 'Available Today',
        nextSlot: '4:30 PM',
        image: 'https://i.pravatar.cc/150?img=33',
        nmcNumber: 'NMC-34567',
        workingPlace: 'Lumbini Eye Institute',
        contactPhone: '+977-9861234569',
        contactEmail: 'dr.bikash.thapa@gmail.com',
        address: 'Bhairahawa, Rupandehi',
      ),
      Doctor(
        id: '4',
        name: 'Dr. Anita Gurung',
        specialization: 'Ophthalmology',
        qualification: 'MBBS, MS (Ophthalmology)',
        experience: '8 years',
        rating: 4.6,
        availability: 'Available Today',
        nextSlot: '11:00 AM',
        image: 'https://i.pravatar.cc/150?img=47',
        nmcNumber: 'NMC-45678',
        workingPlace: 'B.P. Koirala Lions Centre',
        contactPhone: '+977-9841234570',
        contactEmail: 'dr.anita.gurung@gmail.com',
        address: 'Maharajgunj, Kathmandu',
      ),
    ];
  }
}
