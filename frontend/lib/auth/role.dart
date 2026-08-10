/// Mirrors the backend `Role` enum; shapes the UI only, the backend still authorizes.
enum Role {
  patient('PATIENT'),
  receptionist('RECEPTIONIST'),
  doctor('DOCTOR'),
  admin('ADMIN');

  const Role(this.wireName);

  /// The value the backend sends, matching `Role.name()` on the server.
  final String wireName;

  /// Returns null for an unrecognised role, which callers reject rather than guess at.
  static Role? tryParse(String? value) {
    for (final role in Role.values) {
      if (role.wireName == value) {
        return role;
      }
    }
    return null;
  }

  bool get isClinicStaff =>
      this == Role.doctor || this == Role.receptionist || this == Role.admin;
}
