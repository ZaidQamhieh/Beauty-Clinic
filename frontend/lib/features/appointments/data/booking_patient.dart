/// The patient details the booking flow needs.
class BookingPatient {
  const BookingPatient({
    required this.userId,
    required this.healthFormComplete,
  });

  final String userId;
  final bool healthFormComplete;

  factory BookingPatient.fromJson(Map<String, dynamic> json) {
    return BookingPatient(
      userId: json['id'] as String,
      // Skin type marks the intake form filled.
      healthFormComplete: json['skinType'] != null,
    );
  }
}
