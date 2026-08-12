import 'dart:convert';

import 'package:beauty_clinic_app/auth/role.dart';
import 'package:beauty_clinic_app/auth/token_pair.dart';
import 'package:beauty_clinic_app/features/products/data/product_api.dart';
import 'package:beauty_clinic_app/features/products/presentation/product_catalog_screen.dart';
import 'package:beauty_clinic_app/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';

void main() {
  testWidgets('admin can view and add a product', (tester) async {
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
    final product = {
      'id': 'product-id',
      'brand': 'CERAVE',
      'productType': 'CLEANSER',
      'category': 'Skin care',
      'stockQuantity': 5,
      'ingredients': <String>[],
    };
    final adapter = QueueAdapter([
      (_) => _listResponse([product]),
      (_) => jsonResponse(201, product),
      (_) => _listResponse([product]),
    ]);
    final client = ApiClient(session, dio: testDio(adapter));
    addTearDown(() {
      client.close();
      session.dispose();
    });
    await session.initialize();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductCatalogScreen(api: ProductApi(client), canManage: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cerave Cleanser'), findsOneWidget);

    await tester.tap(find.text('Add Product'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Skin care');
    await tester.enterText(find.byType(TextFormField).last, '10');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(adapter.requests[1].method, 'POST');
    expect(adapter.requests[1].path, '/api/products');
  });
}

ResponseBody _listResponse(List<Object> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
