import '../../../network/api_client.dart';
import 'clinical_intake_schema.dart';

/// Talks to the clinical-intake endpoints on `PatientController`.
///
/// Two identical shapes, two audiences: `/me/clinical` is a patient editing
/// their own record (`@PatientOnly`); `/{id}/clinical` is staff editing
/// someone else's (`@ClinicalReader` / `@ClinicalWriter`). Both speak the
/// same `EditClinicalProfileRequest` / `PatientRecordResponse` shape, so
/// both go through [ClinicalIntakeSchema] for the JSON <-> form-values
/// conversion.
class ClinicalIntakeApi {
  const ClinicalIntakeApi(this._client);

  final ApiClient _client;

  /// `GET /api/patients/me` — the patient's own full record; only the
  /// clinical fields are pulled out for the form.
  Future<Map<String, dynamic>> fetchOwn() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/patients/me',
    );
    return ClinicalIntakeSchema.fromResponseJson(response.data!);
  }

  /// `PUT /api/patients/me/clinical`.
  Future<Map<String, dynamic>> saveOwn(Map<String, dynamic> values) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/api/patients/me/clinical',
      data: ClinicalIntakeSchema.toRequestJson(values),
    );
    return ClinicalIntakeSchema.fromResponseJson(response.data!);
  }

  /// `GET /api/patients/{id}/clinical` — staff reading a patient's intake.
  Future<Map<String, dynamic>> fetchForPatient(String patientId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/patients/$patientId/clinical',
    );
    return ClinicalIntakeSchema.fromResponseJson(response.data!);
  }

  /// `PUT /api/patients/{id}/clinical` — staff editing a patient's intake.
  Future<Map<String, dynamic>> saveForPatient(
      String patientId,
      Map<String, dynamic> values,
      ) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/api/patients/$patientId/clinical',
      data: ClinicalIntakeSchema.toRequestJson(values),
    );
    return ClinicalIntakeSchema.fromResponseJson(response.data!);
  }

  /// Admin-only directory of clinical records, optionally filtered by patient details.
  Future<List<Map<String, dynamic>>> searchClinical(String query) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/patients/clinical',
      queryParameters: {'q': query, 'size': 50, 'sort': 'user.lastName,asc'},
    );
    final body = response.data!;
    final content = body['content'] as List<dynamic>? ?? const [];
    return content.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchHistory(String patientId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/patients/$patientId/clinical/history',
      queryParameters: {'size': 50, 'sort': 'createdAt,desc'},
    );
    return (response.data!['content'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }
}
