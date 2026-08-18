import '../../../network/api_client.dart';
import 'doctor_summary.dart';

/// Reads the doctor directory.
class DoctorApi {
  DoctorApi(this._client);

  final ApiClient _client;

  Future<List<DoctorSummary>>? _list;

  /// Roster barely moves; one fetch per session.
  Future<List<DoctorSummary>> list() async {
    final cached = _list;
    if (cached != null) return cached;

    final pending = _fetch();
    _list = pending;
    try {
      return await pending;
    } catch (_) {
      _list = null;
      rethrow;
    }
  }

  Future<List<DoctorSummary>> _fetch() async {
    final response = await _client.get<List<dynamic>>('/api/doctors');
    final data = response.data ?? const [];
    return data
        .map(
          (json) =>
              DoctorSummary.fromJson(Map<String, dynamic>.from(json as Map)),
        )
        .toList();
  }
}
