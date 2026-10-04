import 'package:flutter/foundation.dart';

class AppConfig {
  static final String defaultBaseUrl = (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
      ? 'http://10.0.2.2:8080'
      : 'http://localhost:8080';

  static String baseUrl = defaultBaseUrl;

  static String get kahootHubUrl => '$baseUrl/hubs/kahoot';
  static String get apiUrl => '$baseUrl/api';
}
