import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import 'app_config.dart';

class InstalledAppVersion {
  const InstalledAppVersion(this.name, this.code, this.abis);

  final String name;
  final int code;
  final List<String> abis;
}

class AndroidUpdate {
  const AndroidUpdate(this.name, this.url);

  final String name;
  final Uri url;
}

class AppUpdates {
  AppUpdates({Dio? http})
    : _http =
          http ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            ),
          );

  static const _platform = MethodChannel('quizms/app_updates');
  final Dio _http;

  Future<InstalledAppVersion> installed() async {
    final info = await _platform.invokeMapMethod<String, dynamic>('installed');
    return InstalledAppVersion(
      info!['versionName'] as String,
      info['versionCode'] as int,
      (info['abis'] as List).cast<String>(),
    );
  }

  Future<AndroidUpdate?> check() async {
    final current = await installed();
    // Release metadata comes from the build's backend, not a Kahoot server
    // entered at runtime. This client never sends the user's sign-in token.
    final response = await _http.get<Object?>(
      Uri.parse(AppConfig.defaultBaseUrl)
          .resolve('/api/app-updates/android')
          .toString(),
      options: Options(
        validateStatus: (status) =>
            status == 200 || status == 204 || status == 404,
      ),
    );
    if (response.statusCode != 200) return null;

    final release = response.data as Map<String, dynamic>;
    final code = release['versionCode'] as int;
    final abi = release['abi'] as String;
    if (code <= current.code ||
        (abi != 'universal' && !current.abis.contains(abi))) {
      return null;
    }

    final url = Uri.parse(release['updateUrl'] as String);
    if (url.scheme != 'https' || url.host.isEmpty || url.userInfo.isNotEmpty) {
      throw const FormatException('Expected an HTTPS release URL.');
    }
    return AndroidUpdate(release['versionName'] as String, url);
  }

  Future<void> open(AndroidUpdate update) =>
      _platform.invokeMethod<void>('openUpdate', update.url.toString());
}
