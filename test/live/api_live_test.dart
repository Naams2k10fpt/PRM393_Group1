// Calls a real backend. Skipped unless LIVE_API_BASE_URL is set, e.g.
//   LIVE_API_BASE_URL=http://localhost:5039 flutter test test/live
// Uses the shared demo account and only reads data / sends harmless requests.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_management_mobile/core/config/app_config.dart';
import 'package:quiz_management_mobile/data/api/api_client.dart';
import 'package:quiz_management_mobile/data/api/api_exception.dart';
import 'package:quiz_management_mobile/data/api/token_storage.dart';
import 'package:quiz_management_mobile/data/repositories/auth_repository.dart';
import 'package:quiz_management_mobile/data/repositories/profile_repository.dart';

void main() {
  final baseUrl = Platform.environment['LIVE_API_BASE_URL'];
  final skip = baseUrl == null ? 'Set LIVE_API_BASE_URL to run against a backend' : null;

  test('login, read profile, then a revoked token signs out', () async {
    AppConfig.baseUrl = baseUrl!;
    final tokens = InMemoryTokenStorage();
    final api = ApiClient(tokens: tokens);
    var unauthorized = 0;
    api.onUnauthorized = () => unauthorized++;

    final user = await AuthRepository(api, tokens).login('user.demo@quiz.local', 'Test@123456');
    expect(user.email, 'user.demo@quiz.local');

    final profile = await ProfileRepository(api, tokens).getProfile();
    expect(profile.id, user.id);

    await tokens.write('garbage');
    await expectLater(ProfileRepository(api, tokens).getProfile(), throwsA(isA<ApiException>()));
    expect(unauthorized, 1);
    expect(tokens.token, isNull);
  }, skip: skip);

  test('wrong password maps to invalid_credentials', () async {
    AppConfig.baseUrl = baseUrl!;
    final api = ApiClient(tokens: InMemoryTokenStorage());

    await expectLater(
      AuthRepository(api, InMemoryTokenStorage()).login('nobody.live-test@quiz.local', 'whatever-password'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'invalid_credentials')),
    );
  }, skip: skip);
}
