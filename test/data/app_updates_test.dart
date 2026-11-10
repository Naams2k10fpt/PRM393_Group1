import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_management_mobile/core/config/app_updates.dart';

import '../support/fake_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('quizms/app_updates');
  final release = {
    'versionName': '1.0.0',
    'versionCode': 2002,
    'abi': 'arm64-v8a',
    'updateUrl': 'https://example.com/release.apk',
  };
  late FakeAdapter adapter;
  late AppUpdates updates;

  setUp(() {
    adapter = FakeAdapter(200, release);
    updates = AppUpdates(http: Dio()..httpClientAdapter = adapter);
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {
        'versionName': '1.0.0',
        'versionCode': 2001,
        'abis': ['arm64-v8a'],
      },
    );
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'offers a newer Android build even when the version name is unchanged',
    () async {
      final update = await updates.check();
      expect(update?.url, Uri.parse(release['updateUrl'] as String));
      expect(adapter.requests.single.uri.path, '/api/app-updates/android');
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    },
  );

  test(
    'skips the same or older builds, incompatible APKs and unavailable feeds',
    () async {
      adapter.body = {...release, 'versionCode': 2001};
      expect(await updates.check(), isNull);
      adapter.body = {...release, 'versionCode': 2000};
      expect(await updates.check(), isNull);
      adapter.body = {...release, 'abi': 'x86_64'};
      expect(await updates.check(), isNull);
      adapter.status = 404;
      adapter.body = 'not found';
      expect(await updates.check(), isNull);
    },
  );

  test('rejects an insecure release link', () async {
    adapter.body = {...release, 'updateUrl': 'http://example.com/release.apk'};
    await expectLater(updates.check(), throwsFormatException);
  });
}
