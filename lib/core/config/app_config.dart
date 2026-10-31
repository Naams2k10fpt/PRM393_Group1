/// Backend location. Set at build time with `--dart-define=API_BASE_URL=http://localhost:5039`;
/// defaults to the local development backend. Set API_BASE_URL when building for a phone.
class AppConfig {
  AppConfig._();

  static const String localBaseUrl = 'http://localhost:5039';
  static const String productionBaseUrl = 'https://prn232-group5.onrender.com';

  static const String defaultBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: localBaseUrl);

  /// Mutable so the Kahoot entry screen's server dialog can point the app elsewhere at runtime.
  /// The API client reads it on every request.
  static String baseUrl = defaultBaseUrl;

  static String get kahootHubUrl => '$baseUrl/hubs/kahoot';
  static String get apiUrl => '$baseUrl/api';
}
