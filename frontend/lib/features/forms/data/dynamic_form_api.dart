import '../../../network/api_client.dart';
import '../domain/form_field_schema.dart';
import '../domain/form_schema.dart';
import 'clinical_intake_schema.dart';

/// Talks to [DynamicFormController] at `/api/forms/clinical-intake/...`.
class DynamicFormApi {
  const DynamicFormApi(this._client);

  final ApiClient _client;

  /// `GET /api/forms/clinical-intake` — active questions for the patient UI.
  Future<FormSchema> fetchPublishedSchema() async {
    final response = await _client.get<List<dynamic>>(
      '/api/forms/clinical-intake',
    );
    return _schemaFromQuestions(response.data ?? const []);
  }

  /// `GET /api/forms/clinical-intake/answers/me`.
  Future<Map<String, dynamic>> fetchOwnAnswers() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/forms/clinical-intake/answers/me',
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  /// `PUT /api/forms/clinical-intake/answers/me`.
  Future<Map<String, dynamic>> saveOwnAnswers(
    Map<String, dynamic> values,
  ) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/api/forms/clinical-intake/answers/me',
      data: {'answers': values},
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  /// Admin: `GET /api/forms/clinical-intake/admin/questions`.
  Future<List<Map<String, dynamic>>> fetchAdminQuestionsRaw() async {
    final response = await _client.get<List<dynamic>>(
      '/api/forms/clinical-intake/admin/questions',
    );
    return (response.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map((question) => Map<String, dynamic>.from(question))
        .toList();
  }

  /// Admin: `POST /api/forms/clinical-intake/admin/questions`.
  Future<void> createQuestion(Map<String, dynamic> question) async {
    await _client.post<void>(
      '/api/forms/clinical-intake/admin/questions',
      data: _toRequestJson(question),
    );
  }

  /// Admin: `PUT /api/forms/clinical-intake/admin/questions/{id}`.
  Future<void> updateQuestion(String id, Map<String, dynamic> question) async {
    await _client.put<void>(
      '/api/forms/clinical-intake/admin/questions/$id',
      data: _toRequestJson(question),
    );
  }

  /// Admin: `DELETE /api/forms/clinical-intake/admin/questions/{id}` (soft-hide).
  Future<void> deactivateQuestion(String id) async {
    await _client.delete<void>(
      '/api/forms/clinical-intake/admin/questions/$id',
    );
  }

  /// Admin: `POST /api/forms/clinical-intake/admin/questions/{id}/activate`.
  Future<void> activateQuestion(String id) async {
    await _client.post<void>(
      '/api/forms/clinical-intake/admin/questions/$id/activate',
    );
  }

  static FormSchema _schemaFromQuestions(List<dynamic> questions) {
    final baselineFieldMap = {
      for (final f in ClinicalIntakeSchema.schema.fields) f.id: f,
    };

    final fields = <FormFieldSchema>[];
    for (final raw in questions) {
      final question = Map<String, dynamic>.from(raw as Map);
      final fieldKey = question['fieldKey'] as String;
      final type = FormFieldTypeWire.fromWire(question['fieldType'] as String);
      final baselineField = baselineFieldMap[fieldKey];

      final rawOptions = (question['options'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
            (option) => FormOption(
              value: option['value'] as String,
              label: option['label'] as String,
            ),
          )
          .toList();

      final optionMap = <String, FormOption>{};
      if (baselineField != null) {
        for (final opt in baselineField.options) {
          optionMap[opt.value] = opt;
        }
      }
      for (final opt in rawOptions) {
        optionMap[opt.value] = opt;
      }

      fields.add(
        FormFieldSchema(
          id: fieldKey,
          label: question['label'] as String,
          type: type,
          required: question['required'] == true,
          helpText: question['helpText'] as String?,
          options: optionMap.values.toList(),
          maxSelections: type == FormFieldType.multiSelect ? 20 : null,
        ),
      );
    }

    return FormSchema(
      id: 'clinical-intake',
      title: 'Clinic Forms',
      description:
          'Your clinic health form. Required questions must be answered before saving.',
      fields: fields.isNotEmpty ? fields : ClinicalIntakeSchema.schema.fields,
    );
  }

  static Map<String, dynamic> _toRequestJson(Map<String, dynamic> question) {
    return {
      'fieldKey': question['fieldKey'],
      'label': question['label'],
      'helpText': question['helpText'],
      'fieldType': question['fieldType'],
      'required': question['required'] ?? false,
      'displayOrder': question['displayOrder'] ?? 999,
      'options': question['options'] ?? const [],
    };
  }
}
