import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_management_mobile/core/config/app_config.dart';
import 'package:quiz_management_mobile/data/api/api_client.dart';
import 'package:quiz_management_mobile/data/api/api_exception.dart';
import 'package:quiz_management_mobile/data/api/token_storage.dart';
import 'package:quiz_management_mobile/data/repositories/auth_repository.dart';
import 'package:quiz_management_mobile/data/repositories/profile_repository.dart';

/// Answers every request with [status]/[body] and remembers what was sent.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.status, this.body);

  int status;
  Object? body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late FakeAdapter adapter;
  late InMemoryTokenStorage tokens;
  late ApiClient api;

  setUp(() {
    adapter = FakeAdapter(200, {});
    tokens = InMemoryTokenStorage();
    api = ApiClient(tokens: tokens, dio: Dio()..httpClientAdapter = adapter);
  });

  test('uses AppConfig.baseUrl and attaches the bearer token', () async {
    tokens.token = 'abc';

    await api.get('/api/profile');

    final request = adapter.requests.single;
    expect(request.uri.toString(), '${AppConfig.baseUrl}/api/profile');
    expect(request.headers['Authorization'], 'Bearer abc');
  });

  test('auth: false calls carry no token', () async {
    tokens.token = 'abc';

    await api.post('/api/auth/login', data: {}, auth: false);

    expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('backend error body becomes ApiException with field errors', () async {
    adapter
      ..status = 400
      ..body = {
        'code': 'validation_failed',
        'message': 'Dữ liệu không hợp lệ.',
        'errors': {
          'email': ['Email không hợp lệ.'],
        },
      };

    final error = await api.post('/api/auth/login', auth: false).then<ApiException?>((_) => null,
        onError: (Object e) => e as ApiException);

    expect(error!.code, 'validation_failed');
    expect(error.statusCode, 400);
    expect(error.fieldError('email'), 'Email không hợp lệ.');
  });

  test('401 with a token clears it and calls onUnauthorized once', () async {
    tokens.token = 'revoked';
    var calls = 0;
    api.onUnauthorized = () => calls++;
    adapter
      ..status = 401
      ..body = {'code': 'unauthorized', 'message': 'Bạn cần đăng nhập.'};

    await expectLater(api.get('/api/profile'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'unauthorized')));

    expect(tokens.token, isNull);
    expect(calls, 1);
  });

  test('401 on login (no token sent) is a wrong password, not a logout', () async {
    var calls = 0;
    api.onUnauthorized = () => calls++;
    adapter
      ..status = 401
      ..body = {'code': 'invalid_credentials', 'message': 'Email hoặc mật khẩu không đúng.'};

    await expectLater(
      AuthRepository(api, tokens).login('a@b.c', 'x'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'invalid_credentials')),
    );
    expect(calls, 0);
  });

  test('locked_out carries retryAfterSeconds', () async {
    adapter
      ..status = 429
      ..body = {'code': 'locked_out', 'message': 'Thử lại sau 2 phút.', 'retryAfterSeconds': 90};

    await expectLater(
      api.post('/api/auth/login', auth: false),
      throwsA(isA<ApiException>().having((e) => e.retryAfterSeconds, 'retryAfterSeconds', 90)),
    );
  });

  test('a response without an error body still becomes a readable ApiException', () async {
    adapter
      ..status = 502
      ..body = null;

    await expectLater(
      api.get('/api/profile'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiException.unknown)),
    );
  });

  test('login stores the token and returns the user', () async {
    adapter.body = {
      'accessToken': 'new-token',
      'expiresAt': '2026-10-11T00:00:00Z',
      'user': {'id': 'u1', 'username': 'demo', 'email': 'demo@x.y', 'role': 'User', 'avatarUrl': null},
    };

    final user = await AuthRepository(api, tokens).login(' demo@x.y ', 'pw');

    expect(user.username, 'demo');
    expect(tokens.token, 'new-token');
    expect(jsonDecode(jsonEncode(adapter.requests.single.data))['email'], 'demo@x.y');
  });

  test('change password stores the token the backend returns', () async {
    tokens.token = 'old';
    adapter.body = {'accessToken': 'fresh', 'expiresAt': '2026-10-11T00:00:00Z'};

    await ProfileRepository(api, tokens)
        .changePassword(currentPassword: 'a', newPassword: 'b', confirmPassword: 'b');

    expect(tokens.token, 'fresh');
  });
}
