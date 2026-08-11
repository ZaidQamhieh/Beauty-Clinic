import '../../../network/api_client.dart';
import 'product.dart';

class ProductApi {
  const ProductApi(this._client);

  final ApiClient _client;

  Future<Product> getById(String id) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/products/$id',
    );
    return Product.fromJson(response.data!);
  }
}
