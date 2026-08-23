/// A doctor as the directory lists them.
class DoctorSummary {
  const DoctorSummary({
    required this.userId,
    required this.fullName,
    required this.specializations,
    required this.yearsOfExperience,
  });

  final String userId;
  final String fullName;
  final List<String> specializations;
  final int? yearsOfExperience;

  factory DoctorSummary.fromJson(Map<String, dynamic> json) {
    final specs = (json['specializations'] as List?) ?? const [];
    return DoctorSummary(
      userId: json['userId'] as String,
      fullName: json['fullName'] as String? ?? '',
      specializations: specs.map((s) => s as String).toList(),
      yearsOfExperience: (json['yearsOfExperience'] as num?)?.toInt(),
    );
  }

  /// Short category tags, deduped and stable.
  List<String> get categoryTags {
    final tags = <String>{};
    for (final spec in specializations) {
      switch (spec) {
        case 'DERMATOLOGY' || 'COSMETIC_DERMATOLOGY':
          tags.add('Facial');
        case 'LASER_THERAPY':
          tags.add('Laser');
        case 'INJECTABLES':
          tags.add('Injectable');
        case 'AESTHETIC_MEDICINE':
          tags.add('Body');
      }
    }
    return tags.toList();
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
