import 'package:beauty_clinic_app/features/forms/data/dynamic_form_api.dart';
import 'package:beauty_clinic_app/features/forms/presentation/form_builder_admin_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';
import 'helpers/screen_harness.dart';

void main() {
  final questions = <Map<String, dynamic>>[
    {
      'id': '11111111-1111-1111-1111-111111111111',
      'fieldKey': 'pregnant',
      'label': 'Are you pregnant or breastfeeding?',
      'fieldType': 'BOOLEAN',
      'required': true,
      'displayOrder': 1,
      'visibleForGender': 'FEMALE',
      'active': true,
      'options': <String>[],
    },
    {
      'id': '22222222-2222-2222-2222-222222222222',
      'fieldKey': 'skin_type',
      'label': 'How would you describe your skin?',
      'fieldType': 'SINGLE_CHOICE',
      'required': true,
      'displayOrder': 2,
      'visibleForGender': 'BOTH',
      'active': true,
      'options': [
        {'value': 'OILY', 'label': 'Oily'},
        {'value': 'DRY', 'label': 'Dry'},
      ],
    },
  ];

  testWidgets('lists the questions the admin endpoint returns', (tester) async {
    final adapter = QueueAdapter([(_) => jsonListResponse(200, questions)]);

    final bound = await pumpScreen(
      tester,
      adapter,
      (b) => FormBuilderAdminScreen(api: DynamicFormApi(b.client)),
    );

    expect(find.textContaining('pregnant or breastfeeding'), findsWidgets);
    expect(find.textContaining('describe your skin'), findsWidgets);

    bound.dispose();
  });

  testWidgets('a failed load explains itself and offers a retry', (
    tester,
  ) async {
    final adapter = QueueAdapter([
      (_) => jsonResponse(500, const {'detail': 'boom'}),
    ]);

    final bound = await pumpScreen(
      tester,
      adapter,
      (b) => FormBuilderAdminScreen(api: DynamicFormApi(b.client)),
    );

    expect(find.textContaining('Could not load the form'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);

    bound.dispose();
  });

  testWidgets('the add question control is offered', (tester) async {
    final adapter = QueueAdapter([(_) => jsonListResponse(200, questions)]);

    final bound = await pumpScreen(
      tester,
      adapter,
      (b) => FormBuilderAdminScreen(api: DynamicFormApi(b.client)),
    );

    expect(find.text('Add question'), findsWidgets);

    bound.dispose();
  });
}
