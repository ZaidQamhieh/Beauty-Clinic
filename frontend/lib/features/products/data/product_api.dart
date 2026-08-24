import '../../../network/api_client.dart';
import 'product.dart';

class ProductApi {
  const ProductApi(this._client);

  final ApiClient _client;

  Future<List<Product>> list() async {
    final response = await _client.get<List<dynamic>>('/api/products');
    return response.data!
        .map((json) => Product.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }

  Future<Product> getById(String id) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/products/$id',
    );
    return Product.fromJson(response.data!);
  }

  Future<Product> create(ProductInput input) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/products',
      data: input.toJson(),
    );
    return Product.fromJson(response.data!);
  }

  Future<Product> update(String id, ProductInput input) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/api/products/$id',
      data: input.toJson(),
    );
    return Product.fromJson(response.data!);
  }

  Future<void> delete(String id) async {
    await _client.delete<void>('/api/products/$id');
  }

  Future<List<PatientProductRecord>> listForPatient(String patientId) async {
    final response = await _client.get<List<dynamic>>(
      '/api/patients/$patientId/products',
    );
    return (response.data ?? const [])
        .map(
          (item) => PatientProductRecord.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<PatientProductRecord> addForPatient(
    String patientId, {
    required String productId,
    required String source,
    String? startedOn,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/patients/$patientId/products',
      data: {'productId': productId, 'source': source, 'startedOn': startedOn},
    );
    return PatientProductRecord.fromJson(response.data!);
  }

  Future<PatientProductRecord> discontinueForPatient(
    String patientId,
    String patientProductId,
  ) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/api/patients/$patientId/products/$patientProductId/discontinue',
    );
    return PatientProductRecord.fromJson(response.data!);
  }

  Future<List<Product>> prescribedForPatient(String patientId) async {
    final response = await _client.get<List<dynamic>>(
      '/api/patients/$patientId/session-records/prescribed-products',
    );
    return (response.data ?? const [])
        .map((item) => Product.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
