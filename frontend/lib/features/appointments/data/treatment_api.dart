import '../../../network/api_client.dart';
import 'booking_rules.dart';
import 'treatment.dart';

/// Reads the treatment catalogue and booking rules.
class TreatmentApi {
  TreatmentApi(this._client);

  final ApiClient _client;

  BookingRules? _cachedRules;

  Future<List<Treatment>> list() async {
    final response = await _client.get<List<dynamic>>('/api/treatments');
    final data = response.data ?? const [];
    return data
        .map(
          (json) => Treatment.fromJson(Map<String, dynamic>.from(json as Map)),
        )
        .toList();
  }

  /// Static config, so it is fetched once per session.
  Future<BookingRules> rules() async {
    final cached = _cachedRules;
    if (cached != null) return cached;

    final response = await _client.get<Map<String, dynamic>>(
      '/api/treatments/rules',
    );
    return _cachedRules = BookingRules.fromJson(response.data!);
  }
}
