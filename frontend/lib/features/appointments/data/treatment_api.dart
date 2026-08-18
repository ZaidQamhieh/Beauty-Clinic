import '../../../network/api_client.dart';
import 'booking_rules.dart';
import 'treatment.dart';

/// Reads the treatment catalogue and booking rules.
class TreatmentApi {
  TreatmentApi(this._client);

  final ApiClient _client;

  Future<List<Treatment>>? _list;
  Future<BookingRules>? _rules;

  /// Static catalogue, fetched once per session.
  Future<List<Treatment>> list() async {
    final cached = _list;
    if (cached != null) return cached;

    final pending = _fetchList();
    _list = pending;
    try {
      return await pending;
    } catch (_) {
      _list = null;
      rethrow;
    }
  }

  /// Static config, fetched once per session.
  Future<BookingRules> rules() async {
    final cached = _rules;
    if (cached != null) return cached;

    final pending = _fetchRules();
    _rules = pending;
    try {
      return await pending;
    } catch (_) {
      _rules = null;
      rethrow;
    }
  }

  Future<List<Treatment>> _fetchList() async {
    final response = await _client.get<List<dynamic>>('/api/treatments');
    final data = response.data ?? const [];
    return data
        .map(
          (json) => Treatment.fromJson(Map<String, dynamic>.from(json as Map)),
        )
        .toList();
  }

  Future<BookingRules> _fetchRules() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/treatments/rules',
    );
    return BookingRules.fromJson(response.data!);
  }
}
