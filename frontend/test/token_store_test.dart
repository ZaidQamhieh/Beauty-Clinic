import 'package:beauty_clinic_app/auth/token_pair.dart';
import 'package:beauty_clinic_app/auth/token_store.dart';
import 'package:beauty_clinic/auth/role.dart';
import 'package:beauty_clinic/auth/token_pair.dart';
import 'package:beauty_clinic/auth/token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('browser store writes, reads, and clears the complete pair', () async {
    const storage = FlutterSecureStorage();
    final store = BrowserTokenStore(storage: storage);
    final tokens = TokenPair(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      expiresAt: DateTime.utc(2026, 8, 6, 12, 15),
      role: Role.patient,
    );

    await store.write(tokens);
    final restored = await store.read();

    expect(restored?.accessToken, tokens.accessToken);
    expect(restored?.refreshToken, tokens.refreshToken);
    expect(restored?.expiresAt, tokens.expiresAt);

    await store.clear();
    expect(await store.read(), isNull);
  });

  test('browser store clears a partial token write', () async {
    const storage = FlutterSecureStorage();
    final store = BrowserTokenStore(storage: storage);
    await storage.write(key: 'auth.refresh_token', value: 'partial-refresh');

    expect(await store.read(), isNull);
    expect(await storage.read(key: 'auth.refresh_token'), isNull);
  });
}
