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
}
