import 'dart:convert';

import 'package:beauty_clinic_app/auth/auth_session.dart';
import 'package:beauty_clinic_app/features/appointments/data/appointment_api.dart';
import 'package:beauty_clinic_app/features/appointments/data/clinic_time.dart';
import 'package:beauty_clinic_app/features/appointments/data/doctor_api.dart';
import 'package:beauty_clinic_app/features/appointments/data/treatment_api.dart';
import 'package:beauty_clinic_app/features/appointments/presentation/booking_flow_sheet.dart';
import 'package:beauty_clinic_app/features/appointments/presentation/booking_format.dart';
import 'package:beauty_clinic_app/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';

void main() {
  final day = DateTime.now().add(const Duration(days: 2));
  final slotStart = DateTime.utc(day.year, day.month, day.day, 9);

  String iso(DateTime value) => value.toUtc().toIso8601String();

  // Read in the clinic zone.
  String slotPill() => BookingFormat.time12(slotStart);

  // One router, so call order stays free.
  ResponseBody route(RequestOptions options) {
    Object? body;
    if (options.path == '/api/patients/me') {
      body = {'id': 'pat-1', 'skinType': 'NORMAL'};
    } else if (options.path == '/api/treatments') {
      body = [
        {
          'treatmentName': 'CONSULTATION',
          'category': 'FACIAL',
          'durationMinutes': 20,
          'price': 100.0,
        },
        // A second treatment, for two-treatment visits.
        {
          'treatmentName': 'HYDRAFACIAL',
          'category': 'FACIAL',
          'durationMinutes': 60,
          'price': 450.0,
        },
      ];
    } else if (options.path == '/api/treatments/rules') {
      body = {
        'timezone': 'Asia/Hebron',
        'maxHorizonDays': 180,
        'slotGranularityMinutes': 15,
        'turnoverMinutes': 10,
        'cancellationCutoffMinutes': 60,
      };
    } else if (options.path == '/api/doctors') {
      body = [
        {
          'userId': 'doc-1',
          'fullName': 'Dee Oakes',
          'specializations': ['LASER_THERAPY'],
        },
      ];
    } else if (options.path == '/api/appointments/free-slots') {
      body = [
        {
          'practitionerUserId': 'doc-1',
          'practitionerName': 'Dee Oakes',
          'startTime': iso(slotStart),
          'endTime': iso(slotStart.add(const Duration(minutes: 20))),
        },
      ];
    } else {
      body = <String, dynamic>{};
    }

    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  late QueueAdapter adapter;
  late ApiClient client;
  late AuthSession session;

  setUp(() async {
    final authAdapter = QueueAdapter([
      (_) => jsonResponse(200, tokenResponse('access-1', 'refresh-1')),
    ]);
    session = testSession(
      authAdapter,
      MemoryTokenStore(),
      DateTime.utc(2026, 8, 6, 12),
    );
    adapter = QueueAdapter(List.generate(40, (_) => route));
    client = ApiClient(session, dio: testDio(adapter));

    await session.initialize();
    await session.login(email: 'pat@example.com', password: 'password');
  });

  tearDown(() {
    client.close();
    session.dispose();
    ClinicTime.reset();
  });

  Future<void> tapText(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  // Every booking starts by picking here.
  Future<void> chooseTreatment(WidgetTester tester, String label) async {
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> pumpSheet(WidgetTester tester) async {
    // Wide enough for the two-column step.
    tester.view.physicalSize = const Size(1600, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookingFlowSheet(
            treatmentApi: TreatmentApi(client),
            appointmentApi: AppointmentApi(client),
            doctorApi: DoctorApi(client),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<RequestOptions> slotSearches() => adapter.requests
      .where((r) => r.path == '/api/appointments/free-slots')
      .toList();

  // One 403 must not orphan others.
  testWidgets('a forbidden patient read names the real reason', (tester) async {
    adapter = QueueAdapter(
      List.generate(40, (_) {
        return (RequestOptions options) {
          if (options.path == '/api/patients/me') {
            return ResponseBody.fromString(
              jsonEncode({'title': 'Access Denied'}),
              403,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }
          return route(options);
        };
      }),
    );
    client = ApiClient(session, dio: testDio(adapter));

    await pumpSheet(tester);

    expect(find.text('Only patients can book from here.'), findsOneWidget);
    expect(find.textContaining('Could not reach the clinic'), findsNothing);
  });

  testWidgets('add another refetches with the held slot', (tester) async {
    await pumpSheet(tester);

    // Probes the roster's open time first.
    expect(slotSearches(), hasLength(1));
    expect((slotSearches().single.data as Map)['held'], isEmpty);

    await chooseTreatment(tester, 'Consultation');
    await tapText(tester, 'Choose Doctor');
    await tapText(tester, slotPill());

    expect(find.text('Review your visit'), findsOneWidget);

    await tapText(tester, 'Add another');

    // Held items cannot be offered again.
    final held = (slotSearches().last.data as Map)['held'] as List;
    expect(held, hasLength(1));
    expect(held.single['practitionerUserId'], 'doc-1');
    expect(held.single['startTime'], iso(slotStart));
  });

  // Backend rejects a two-day visit.
  testWidgets('a held cart pins the calendar to one day', (tester) async {
    await pumpSheet(tester);

    CalendarDatePicker calendar() =>
        tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));

    // Nothing held, so horizon is open.
    expect(calendar().lastDate.isAfter(calendar().firstDate), isTrue);

    await chooseTreatment(tester, 'Consultation');
    await tapText(tester, 'Choose Doctor');
    await tapText(tester, slotPill());
    await tapText(tester, 'Add another');

    final locked = calendar();
    expect(locked.firstDate, locked.lastDate);
    expect(locked.firstDate, locked.initialDate);
  });

  testWidgets('a different day cannot reach the cart', (tester) async {
    await pumpSheet(tester);

    await chooseTreatment(tester, 'Consultation');
    await tapText(tester, 'Choose Doctor');
    await tapText(tester, slotPill());
    await tapText(tester, 'Add another');

    final searchesBefore = slotSearches().length;
    final pinned = tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .initialDate!;

    // Another day is refused while held.
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged
        .call(pinned.add(const Duration(days: 1)));
    await tester.pumpAndSettle();

    expect(slotSearches(), hasLength(searchesBefore));
    expect(
      tester
          .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
          .initialDate,
      pinned,
    );

    // A different treatment fits the pinned day.
    await chooseTreatment(tester, 'Hydrafacial');
    await tapText(tester, 'Choose Doctor');
    await tapText(tester, slotPill());
    expect(find.text('Review your visit'), findsOneWidget);
    expect(find.text('Consultation'), findsOneWidget);
    expect(find.text('Hydrafacial'), findsOneWidget);
  });

  testWidgets('emptying the cart releases its held times', (tester) async {
    await pumpSheet(tester);

    CalendarDatePicker calendar() =>
        tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));

    await chooseTreatment(tester, 'Consultation');
    await tapText(tester, 'Choose Doctor');
    await tapText(tester, slotPill());
    await tapText(tester, 'Add another');

    // Refetched while one slot is held.
    expect((slotSearches().last.data as Map)['held'], hasLength(1));

    await chooseTreatment(tester, 'Hydrafacial');
    await tapText(tester, 'Choose Doctor');
    await tapText(tester, slotPill());
    expect(find.text('Review your visit'), findsOneWidget);

    final remove = find.byIcon(Icons.close);
    expect(remove, findsNWidgets(2));

    await tester.tap(remove.first);
    await tester.pumpAndSettle();
    expect(find.text('Review your visit'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    // Back on browse, nothing held now.
    expect(find.text('SELECTED TREATMENT'), findsOneWidget);
    expect((slotSearches().last.data as Map)['held'], isEmpty);

    // The date is free to move again.
    expect(calendar().lastDate.isAfter(calendar().firstDate), isTrue);
    expect(find.textContaining('One visit is one day'), findsNothing);
  });

  testWidgets('add another keeps the cart and clears the treatment', (
    tester,
  ) async {
    await pumpSheet(tester);

    await chooseTreatment(tester, 'Consultation');
    await tapText(tester, 'Choose Doctor');
    await tapText(tester, slotPill());
    await tapText(tester, 'Add another');

    // Treatment clears: it is already held.
    expect(find.text('SELECTED TREATMENT'), findsOneWidget);
    expect(find.text('Choose Doctor'), findsNothing);

    // One held slot, so cart survived.
    expect((slotSearches().last.data as Map)['held'], hasLength(1));
  });
}
