import 'package:beauty_clinic_app/features/appointments/data/appointment.dart';
import 'package:beauty_clinic_app/features/appointments/data/appointment_api.dart';
import 'package:beauty_clinic_app/features/appointments/data/booking_patient.dart';
import 'package:beauty_clinic_app/features/appointments/data/booking_rules.dart';
import 'package:beauty_clinic_app/features/appointments/data/free_slot.dart';
import 'package:beauty_clinic_app/features/appointments/data/treatment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Treatment', () {
    test('parses the catalogue entry and humanizes the enum name', () {
      final treatment = Treatment.fromJson({
        'treatmentName': 'LASER_HAIR_REMOVAL',
        'category': 'LASER',
        'durationMinutes': 30,
        'price': 400.0,
      });

      expect(treatment.name, 'LASER_HAIR_REMOVAL');
      expect(treatment.label, 'Laser Hair Removal');
      expect(treatment.durationMinutes, 30);
      expect(treatment.price, 400.0);
    });
  });

  group('BookingRules', () {
    test('parses every rule the client must honour', () {
      final rules = BookingRules.fromJson({
        'timezone': 'Asia/Hebron',
        'maxHorizonDays': 180,
        'slotGranularityMinutes': 15,
        'turnoverMinutes': 10,
        'cancellationCutoffMinutes': 60,
      });

      expect(rules.timezone, 'Asia/Hebron');
      expect(rules.maxHorizonDays, 180);
      expect(rules.cancellationCutoffMinutes, 60);
    });
  });

  group('FreeSlot', () {
    test('parses the ISO instants', () {
      final slot = FreeSlot.fromJson({
        'practitionerUserId': 'doc-1',
        'practitionerName': 'Dr Reem',
        'startTime': '2026-08-11T10:00:00Z',
        'endTime': '2026-08-11T10:20:00Z',
      });

      expect(slot.practitionerName, 'Dr Reem');
      expect(slot.startTime.toUtc(), DateTime.utc(2026, 8, 11, 10));
      expect(slot.endTime.toUtc(), DateTime.utc(2026, 8, 11, 10, 20));
    });
  });

  group('Appointment', () {
    Map<String, dynamic> session(String status, int hour, double price) => {
      'id': 'sess-$hour',
      'appointmentId': 'appt-1',
      'practitionerUserId': 'doc-1',
      'practitionerName': 'Dr Reem',
      'category': 'FACIAL',
      'treatmentName': 'HYDRAFACIAL',
      'priceCharged': price,
      'durationMinutes': 60,
      'status': status,
      'startTime': '2026-08-11T${hour.toString().padLeft(2, '0')}:00:00Z',
      'endTime': '2026-08-11T${hour.toString().padLeft(2, '0')}:30:00Z',
    };

    test(
      'exposes planned sessions in start order and totals every session',
      () {
        final appointment = Appointment.fromJson({
          'id': 'appt-1',
          'patientUserId': 'pat-1',
          'patientName': 'Pat Ient',
          'scheduledAt': '2026-08-11T09:00:00Z',
          'status': 'BOOKED',
          'replacesAppointmentId': null,
          'sessions': [
            session('PLANNED', 14, 100),
            session('CANCELLED', 10, 50),
            session('PLANNED', 9, 200),
          ],
        });

        expect(appointment.isBooked, isTrue);
        // Cancelled dropped; planned sorted 09:00 then 14:00.
        expect(
          appointment.plannedSessions.map((s) => s.startTime.toUtc().hour),
          [9, 14],
        );
      },
    );

    test('reads a reschedule replacement link', () {
      final appointment = Appointment.fromJson({
        'id': 'appt-2',
        'patientUserId': 'pat-1',
        'patientName': 'Pat Ient',
        'scheduledAt': '2026-08-12T09:00:00Z',
        'status': 'BOOKED',
        'replacesAppointmentId': 'appt-1',
        'sessions': const [],
      });

      expect(appointment.replacesAppointmentId, 'appt-1');
    });
  });

  group('AppointmentPage', () {
    test('parses content and the last-page flag', () {
      final page = AppointmentPage.fromJson({
        'content': [
          {
            'id': 'appt-1',
            'patientUserId': 'pat-1',
            'patientName': 'Pat',
            'scheduledAt': '2026-08-11T09:00:00Z',
            'status': 'BOOKED',
            'replacesAppointmentId': null,
            'sessions': const [],
          },
        ],
        'last': false,
      });

      expect(page.items, hasLength(1));
      expect(page.isLast, isFalse);
    });
  });

  group('BookingPatient', () {
    test('is complete only when the skin type is present', () {
      final complete = BookingPatient.fromJson({
        'id': 'pat-1',
        'firstName': 'Pat',
        'lastName': 'Ient',
        'skinType': 'NORMAL',
      });
      final incomplete = BookingPatient.fromJson({
        'id': 'pat-2',
        'firstName': 'No',
        'lastName': 'Form',
        'skinType': null,
      });

      expect(complete.healthFormComplete, isTrue);
      expect(incomplete.healthFormComplete, isFalse);
    });
  });

  group('request serialization', () {
    test('HeldSlot and SessionDraft serialize with UTC ISO instants', () {
      final held = HeldSlot(
        practitionerUserId: 'doc-1',
        startTime: DateTime.utc(2026, 8, 11, 10),
        endTime: DateTime.utc(2026, 8, 11, 10, 20),
      ).toJson();

      expect(held['practitionerUserId'], 'doc-1');
      expect(held['startTime'], '2026-08-11T10:00:00.000Z');

      final draft = SessionDraft(
        practitionerUserId: 'doc-1',
        treatmentName: 'BOTOX',
        startTime: DateTime.utc(2026, 8, 11, 11),
      ).toJson();

      expect(draft['treatmentName'], 'BOTOX');
      expect(draft['startTime'], '2026-08-11T11:00:00.000Z');
    });
  });
}
