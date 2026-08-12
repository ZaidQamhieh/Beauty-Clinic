import '../../../network/api_client.dart';
import 'doctor_summary.dart';

/// Reads the doctor directory.
class DoctorApi {
  const DoctorApi(this._client);

  final ApiClient _client;

  Future<List<DoctorSummary>> list() async {
    final response = await _client.get<List<dynamic>>('/api/doctors');
    final data = response.data ?? const [];
    return data
        .map((json) =>
            DoctorSummary.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }
}
