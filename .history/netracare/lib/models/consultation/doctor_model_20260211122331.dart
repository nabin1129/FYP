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

  Doctor({
    required this.id,
    required this.name,
    required this.specialization,
    required this.experience,
    required this.rating,
    required this.availability,
    required this.nextSlot,
    required this.image,
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
    };
  }

  // Static method to get mock doctors data
  static List<Doctor> getMockDoctors() {
    return [
      Doctor(
        id: '1',
        name: 'Dr. James Smith',
        specialization: 'Ophthalmology',
        experience: '15 years',
        rating: 4.8,
        availability: 'Available Today',
        nextSlot: '2:00 PM',
        image: 'https://i.pravatar.cc/150?img=12',
      ),
      Doctor(
        id: '2',
        name: 'Dr. Maria Garcia',
        specialization: 'Optometry',
        experience: '10 years',
        rating: 4.9,
        availability: 'Available Tomorrow',
        nextSlot: '10:00 AM',
        image: 'https://i.pravatar.cc/150?img=45',
      ),
      Doctor(
        id: '3',
        name: 'Dr. Robert Chen',
        specialization: 'Ophthalmology',
        experience: '12 years',
        rating: 4.7,
        availability: 'Available Today',
        nextSlot: '4:30 PM',
        image: 'https://i.pravatar.cc/150?img=33',
      ),
    ];
  }
}
