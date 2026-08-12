import 'enum_label.dart';

/// A bookable treatment from the backend catalogue.
class Treatment {
  const Treatment({
    required this.name,
    required this.category,
    required this.durationMinutes,
    required this.price,
  });

  /// The TreatmentName constant, sent back verbatim.
  final String name;
  final String category;
  final int durationMinutes;
  final double price;

  factory Treatment.fromJson(Map<String, dynamic> json) {
    return Treatment(
      name: json['treatmentName'] as String,
      category: json['category'] as String,
      durationMinutes: (json['durationMinutes'] as num).toInt(),
      price: (json['price'] as num).toDouble(),
    );
  }

  String get label => humanizeEnum(name);
}
