import 'package:beauty_clinic_app/auth/role.dart';
import 'package:beauty_clinic_app/auth/token_pair.dart';
import 'package:beauty_clinic_app/features/products/data/product_api.dart';
import 'package:beauty_clinic_app/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';

void main() {
  test('loads one product from the product endpoint', () async {
    final store = MemoryTokenStore()
      ..value = TokenPair(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.utc(2026, 8, 11, 13),
        role: Role.patient,
      );
    final session = testSession(
      QueueAdapter(const []),
      store,
      DateTime.utc(2026, 8, 11, 12),
    );
    final adapter = QueueAdapter([
      (_) => jsonResponse(200, {
        'id': 'product-id',
        'brand': 'LA_ROCHE_POSAY',
        'productType': 'SUNSCREEN',
        'ingredients': ['ZINC_OXIDE'],
      }),
    ]);
    final client = ApiClient(session, dio: testDio(adapter));
    addTearDown(() {
      client.close();
      session.dispose();
    });

    await session.initialize();
    final product = await ProductApi(client).getById('product-id');

    expect(adapter.requests.single.path, '/api/products/product-id');
    expect(product.brandLabel, 'La Roche Posay');
    expect(product.typeLabel, 'Sunscreen');
    expect(product.ingredients, ['ZINC_OXIDE']);
  });
}
