import '../../../network/api_client.dart';
import 'session_record.dart';

class SessionRecordApi {
  const SessionRecordApi(this._client);

  final ApiClient _client;

  Future<List<SessionRecord>> listForPatient(String patientId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/patients/$patientId/session-records',
      queryParameters: {'page': 0, 'size': 100},
    );
    return ((response.data?['content'] as List?) ?? const [])
        .map(
          (item) =>
              SessionRecord.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> create({
    required String patientId,
    required String sessionId,
    String? note,
    String? skinReaction,
    String? followUpDate,
    List<String> prescribedProductIds = const [],
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/api/patients/$patientId/session-records',
      data: {
        'sessionId': sessionId,
        'note': note,
        'skinReaction': skinReaction,
        'followUpDate': followUpDate,
        'prescribedProductIds': prescribedProductIds,
      },
    );
  }

  Future<void> amend({
    required String patientId,
    required String recordId,
    String? note,
    String? skinReaction,
    String? followUpDate,
    List<String> prescribedProductIds = const [],
  }) async {
    await _client.put<Map<String, dynamic>>(
      '/api/patients/$patientId/session-records/$recordId/amend',
      data: {
        'note': note,
        'skinReaction': skinReaction,
        'followUpDate': followUpDate,
        'prescribedProductIds': prescribedProductIds,
      },
    );
  }
}
