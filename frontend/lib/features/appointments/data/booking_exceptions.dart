/// A booking the backend refused, with its reason.
class BookingConflictException implements Exception {
  const BookingConflictException(this.message);
  final String message;

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
