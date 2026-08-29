import 'package:beauty_clinic_app/features/products/data/product_api.dart';
import 'package:dio/dio.dart';
import 'package:beauty_clinic_app/features/products/presentation/patient_products_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';

void main() {
  Future<AuthSessionHarness> openScreen(
    WidgetTester tester,
    QueueAdapter adapter, {
    String? patientId = '11111111-1111-1111-1111-111111111111',
  }) async {
    // Test font overflows; real metrics fine.
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final bound = adminHarness(adapter);
    await bound.session.initialize();
    await tester.pumpWidget(
      TickerMode(
        enabled: false,
        child: MaterialApp(
          home: Scaffold(
            body: PatientProductsScreen(
              productApi: ProductApi(bound.client),
              apiClient: bound.client,
              patientId: patientId,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return bound;
  }

  final routine = <Map<String, dynamic>>[
    {
      'id': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      'productId': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'brand': 'ZO_SKIN_HEALTH',
      'productType': 'RETINOID',
      'source': 'PRESCRIBED',
      'startedOn': '2026-08-01',
      'discontinuedOn': null,
    },
  ];

  final catalogue = <Map<String, dynamic>>[
    {
      'id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'name': 'Retinol Complex',
      'brand': 'ZO_SKIN_HEALTH',
      'productType': 'RETINOID',
      'imageUrl': null,
      'stockQuantity': 12,
      'ingredients': ['RETINOL'],
    },
  ];

  testWidgets('a missing patient id explains the account is unknown', (
    tester,
  ) async {
    final bound = await openScreen(
      tester,
      QueueAdapter(const []),
      patientId: null,
    );

    expect(
      find.text('We could not tell which account this is.'),
      findsOneWidget,
    );

    bound.dispose();
  });

  testWidgets('a failed load surfaces the products error message', (
    tester,
  ) async {
    final adapter = QueueAdapter([
      (_) => jsonResponse(500, const {'detail': 'boom'}),
      (_) => jsonResponse(500, const {'detail': 'boom'}),
      (_) => jsonResponse(500, const {'detail': 'boom'}),
      (_) => jsonResponse(500, const {'detail': 'boom'}),
    ]);

    final bound = await openScreen(tester, adapter);

    expect(find.text('Could not load your products.'), findsOneWidget);

    bound.dispose();
  });

  testWidgets('a loaded routine renders the header and the product', (
    tester,
  ) async {
    // Future.wait races, so answer by path.
    ResponseBody byPath(RequestOptions request) {
      if (request.path == '/api/products') {
        return jsonListResponse(200, catalogue);
      }
      if (request.path.endsWith('/session-records')) {
        return jsonResponse(200, const {'content': []});
      }
      if (request.path.endsWith('/products')) {
        return jsonListResponse(200, routine);
      }
      return jsonListResponse(200, const []);
    }

    final adapter = QueueAdapter([byPath, byPath, byPath, byPath]);

    final bound = await openScreen(tester, adapter);

    expect(find.text('My products'), findsOneWidget);
    expect(find.textContaining('Skin Health'), findsWidgets);

    bound.dispose();
  });
}
