import 'dart:convert';

import 'package:beauty_clinic_app/auth/role.dart';
import 'package:beauty_clinic_app/auth/token_pair.dart';
import 'package:beauty_clinic_app/features/products/data/product.dart';
import 'package:beauty_clinic_app/features/products/data/product_api.dart';
import 'package:beauty_clinic_app/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';

void main() {
  test('product API reads and saves products', () async {
    final session = testSession(
      QueueAdapter(const []),
      MemoryTokenStore()
        ..value = TokenPair(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          expiresAt: DateTime.utc(2026, 8, 11, 13),
          role: Role.admin,
        ),
      DateTime.utc(2026, 8, 11, 12),
    );
    final adapter = QueueAdapter([
      (_) => jsonResponse(200, _product()),
      (_) => _listResponse([_product()]),
      (_) => jsonResponse(201, _product()),
      (_) => jsonResponse(200, _product(stock: 3)),
    ]);
    final client = ApiClient(session, dio: testDio(adapter));
    addTearDown(() {
      client.close();
      session.dispose();
    });
    const input = ProductInput(
      brand: 'LA_ROCHE_POSAY',
      productType: 'SUNSCREEN',
      category: 'Sun care',
      stockQuantity: 7,
      ingredients: ['ZINC_OXIDE'],
    );

    await session.initialize();
    final api = ProductApi(client);
    final product = await api.getById('product-id');
    final products = await api.list();
    await api.create(input);
    final updated = await api.update('product-id', input);

    expect(product.brandLabel, 'La Roche Posay');
    expect(products.single.id, 'product-id');
    expect(updated.stockQuantity, 3);
    expect(adapter.requests.map((request) => request.method).toList(), [
      'GET',
      'GET',
      'POST',
      'PUT',
    ]);
    expect(adapter.requests.last.path, '/api/products/product-id');
  });
}

Map<String, dynamic> _product({int stock = 7}) => {
  'id': 'product-id',
  'brand': 'LA_ROCHE_POSAY',
  'productType': 'SUNSCREEN',
  'category': 'Sun care',
  'stockQuantity': stock,
  'ingredients': ['ZINC_OXIDE'],
};

ResponseBody _listResponse(List<Object> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
