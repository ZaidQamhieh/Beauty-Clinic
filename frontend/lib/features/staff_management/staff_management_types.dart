part of 'staff_management_screen.dart';

class StaffMember {
  const StaffMember({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.dateOfBirth,
    required this.gender,
    required this.role,
    required this.status,
    required this.specializations,
    required this.yearsOfExperience,
  });

  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final DateTime? dateOfBirth;
  final String gender;
  final String role;
  final String status;
  final List<String> specializations;
  final int? yearsOfExperience;

  String get fullName => '$firstName $lastName'.trim();

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    final doctorProfile = json['doctorProfile'];
    final profileMap = doctorProfile is Map<String, dynamic>
        ? doctorProfile
        : <String, dynamic>{};

    final rawSpecializations = profileMap['specializations'];
    final parsedSpecializations = rawSpecializations is List
        ? rawSpecializations.map((entry) => entry.toString()).toList()
        : <String>[];

    return StaffMember(
      userId: (json['id'] ?? '').toString(),
      firstName: (json['firstName'] ?? '').toString(),
      lastName: (json['lastName'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      dateOfBirth: DateTime.tryParse((json['dateOfBirth'] ?? '').toString()),
      gender: (json['gender'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      specializations: parsedSpecializations,
      yearsOfExperience: profileMap['yearsOfExperience'] as int?,
    );
  }
}

enum _StaffRole { doctor, receptionist }

enum _StaffFilter { all, doctor, receptionist }

enum _Gender { male, female, other }

enum _AccountStatus { active, invited, deactivated }

enum _DoctorSpecialization {
  dermatology,
  cosmeticDermatology,
  laserTherapy,
  injectables,
  aestheticMedicine,
}
