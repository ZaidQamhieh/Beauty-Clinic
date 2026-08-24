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

enum _AccountStatus { active, deactivated }

enum _DoctorSpecialization {
  dermatology,
  cosmeticDermatology,
  laserTherapy,
  injectables,
  aestheticMedicine,
}

extension _DoctorSpecializationLabels on _DoctorSpecialization {
  String get apiValue => switch (this) {
    _DoctorSpecialization.dermatology => 'DERMATOLOGY',
    _DoctorSpecialization.cosmeticDermatology => 'COSMETIC_DERMATOLOGY',
    _DoctorSpecialization.laserTherapy => 'LASER_THERAPY',
    _DoctorSpecialization.injectables => 'INJECTABLES',
    _DoctorSpecialization.aestheticMedicine => 'AESTHETIC_MEDICINE',
  };

  String get label => switch (this) {
    _DoctorSpecialization.dermatology => 'Dermatology',
    _DoctorSpecialization.cosmeticDermatology => 'Cosmetic Dermatology',
    _DoctorSpecialization.laserTherapy => 'Laser Therapy',
    _DoctorSpecialization.injectables => 'Injectables',
    _DoctorSpecialization.aestheticMedicine => 'Aesthetic Medicine',
  };
}

enum _ExperienceFilter { all, junior, mid, senior, expert }

extension _ExperienceFilterLabels on _ExperienceFilter {
  String get label => switch (this) {
    _ExperienceFilter.all => 'All experience',
    _ExperienceFilter.junior => '0-2 years',
    _ExperienceFilter.mid => '3-5 years',
    _ExperienceFilter.senior => '6-10 years',
    _ExperienceFilter.expert => '10+ years',
  };

  bool matches(int? years) {
    return switch (this) {
      _ExperienceFilter.all => true,
      _ExperienceFilter.junior => years != null && years <= 2,
      _ExperienceFilter.mid => years != null && years >= 3 && years <= 5,
      _ExperienceFilter.senior => years != null && years >= 6 && years <= 10,
      _ExperienceFilter.expert => years != null && years > 10,
    };
  }
}
