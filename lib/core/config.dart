class AppConfig {
  // Thay đổi URL này thành IP LAN của bạn hoặc link Render
  // Đối với Android Emulator: 10.0.2.2 trỏ về localhost máy tính
  static const String defaultBaseUrl = 'http://10.0.2.2:5039';

  static String baseUrl = defaultBaseUrl;

  static String get kahootHubUrl => '$baseUrl/hubs/kahoot';
  static String get apiUrl => '$baseUrl/api';
}
