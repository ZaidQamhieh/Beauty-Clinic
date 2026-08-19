/// A booking the backend refused, with reason.
class BookingConflictException implements Exception {
  const BookingConflictException(this.message, {this.treatmentName});

  final String message;

  /// The pick that lost; null when visit-wide.
  final String? treatmentName;

  @override
  String toString() => message;
}

/// Malformed or invalid request (HTTP 400).
class BookingValidationException implements Exception {
  const BookingValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}
