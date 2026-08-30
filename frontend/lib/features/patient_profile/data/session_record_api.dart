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

  /// Returns the saved record, so a caller can update its own state from
  /// it directly instead of re-fetching everything just to see what it
  /// itself just wrote.
  Future<SessionRecord> create({
    required String patientId,
    required String sessionId,
    String? note,
    String? skinReaction,
    String? followUpDate,
    List<String> prescribedProductIds = const [],
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/patients/$patientId/session-records',
      data: {
        'sessionId': sessionId,
        'note': note,
        'skinReaction': skinReaction,
        'followUpDate': followUpDate,
        'prescribedProductIds': prescribedProductIds,
      },
    );
    return SessionRecord.fromJson(response.data!);
  }

  /// Returns the new record this amendment created - amending never edits
  /// the original row in place, it appends a correction that supersedes it.
  Future<SessionRecord> amend({
    required String patientId,
    required String recordId,
    String? note,
    String? skinReaction,
    String? followUpDate,
    List<String> prescribedProductIds = const [],
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/api/patients/$patientId/session-records/$recordId/amend',
      data: {
        'note': note,
        'skinReaction': skinReaction,
        'followUpDate': followUpDate,
        'prescribedProductIds': prescribedProductIds,
      },
    );
    return SessionRecord.fromJson(response.data!);
  }
}
