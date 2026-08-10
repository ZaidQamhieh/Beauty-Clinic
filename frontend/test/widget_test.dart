import 'package:flutter_test/flutter_test.dart';
import 'package:beauty_clinic_app/app.dart';

void main() {
  testWidgets('Beauty Clinic app shell smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BeautyClinicApp());
    expect(find.text('YASMINE'), findsWidgets);
  });
}
