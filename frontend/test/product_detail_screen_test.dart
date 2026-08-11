import 'dart:async';

import 'package:beauty_clinic_app/features/products/data/product.dart';
import 'package:beauty_clinic_app/features/products/presentation/product_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const product = Product(
    id: 'product-id',
    brand: 'CERAVE',
    productType: 'MOISTURIZER',
    ingredients: ['HYALURONIC_ACID', 'CERAMIDES'],
  );

  testWidgets('shows loading then the product details', (tester) async {
    final result = Completer<Product>();
    await tester.pumpWidget(
      MaterialApp(
        home: ProductDetailScreen(
          productId: product.id,
          loadProduct: (_) => result.future,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    result.complete(product);
    await tester.pumpAndSettle();

    expect(find.text('Cerave Moisturizer'), findsOneWidget);
    expect(find.text('Hyaluronic Acid'), findsOneWidget);
    expect(find.text('Ceramides'), findsOneWidget);
  });

  testWidgets('shows a generic error and retries', (tester) async {
    var attempts = 0;
    Future<Product> loadProduct(String _) async {
      attempts += 1;
      if (attempts == 1) {
        throw Exception('raw server detail');
      }
      return product;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: ProductDetailScreen(
          productId: product.id,
          loadProduct: loadProduct,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to load product.'), findsOneWidget);
    expect(find.textContaining('raw server detail'), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Cerave Moisturizer'), findsOneWidget);
  });
}
