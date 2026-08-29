import 'package:beauty_clinic_app/auth/auth_session.dart';
import 'package:beauty_clinic_app/auth/role.dart';
import 'package:beauty_clinic_app/auth/token_pair.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';

void main() {
  final now = DateTime.utc(2026, 8, 6, 12);

  test('patient role identified correctly', () {
    final token = TokenPair(
      accessToken: 'token',
      refreshToken: 'refresh',
      expiresAt: DateTime.utc(2026, 8, 11, 13),
      role: Role.patient,
    );
    expect(token.role, Role.patient);
    expect(token.role == Role.patient, isTrue);
    expect(token.role == Role.admin, isFalse);
  });

  test('admin role identified correctly', () {
    final token = TokenPair(
      accessToken: 'token',
      refreshToken: 'refresh',
      expiresAt: DateTime.utc(2026, 8, 11, 13),
      role: Role.admin,
    );
    expect(token.role, Role.admin);
    expect(token.role == Role.admin, isTrue);
    expect(token.role == Role.patient, isFalse);
  });

  test('doctor role identified correctly', () {
    final token = TokenPair(
      accessToken: 'token',
      refreshToken: 'refresh',
      expiresAt: DateTime.utc(2026, 8, 11, 13),
      role: Role.doctor,
    );
    expect(token.role, Role.doctor);
    expect(token.role == Role.doctor, isTrue);
    expect(token.role == Role.admin, isFalse);
  });

  test('receptionist role identified correctly', () {
    final token = TokenPair(
      accessToken: 'token',
      refreshToken: 'refresh',
      expiresAt: DateTime.utc(2026, 8, 11, 13),
      role: Role.receptionist,
    );
    expect(token.role, Role.receptionist);
    expect(token.role == Role.receptionist, isTrue);
  });

  test('session stores and validates role', () async {
    final store = MemoryTokenStore();
    final adapter = QueueAdapter([
      (_) => jsonResponse(
        200,
        tokenResponse('access-1', 'refresh-1', role: 'ADMIN'),
      ),
    ]);
    final session = testSession(adapter, store, now);
    addTearDown(session.dispose);

    await session.initialize();
    await session.login(email: 'admin@example.com', password: 'password');

    expect(session.status, AuthStatus.authenticated);
    final stored = await store.read();
    expect(stored?.role, Role.admin);
  });

  test('session persists role across reinit', () async {
    final store = MemoryTokenStore();
    store.value = TokenPair(
      accessToken: 'token',
      refreshToken: 'refresh',
      expiresAt: DateTime.utc(2026, 8, 11, 13),
      role: Role.doctor,
    );

    final adapter = QueueAdapter(const []);
    final session = testSession(adapter, store, now);
    addTearDown(session.dispose);

    await session.initialize();

    expect(session.status, AuthStatus.authenticated);
    final current = await store.read();
    expect(current?.role, Role.doctor);
  });

  test('different roles have different access levels', () {
    final adminToken = TokenPair(
      accessToken: 'admin-token',
      refreshToken: 'refresh',
      expiresAt: DateTime.utc(2026, 8, 11, 13),
      role: Role.admin,
    );

    final patientToken = TokenPair(
      accessToken: 'patient-token',
      refreshToken: 'refresh',
      expiresAt: DateTime.utc(2026, 8, 11, 13),
      role: Role.patient,
    );

    expect(adminToken.role != patientToken.role, isTrue);
    expect(adminToken.role == Role.admin, isTrue);
    expect(patientToken.role == Role.patient, isTrue);
  });
}
